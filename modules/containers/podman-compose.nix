{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkIf mkMerge mkOption types optionalString concatStringsSep mapAttrsToList;

  cfg = config.modules.caddyCompose;

  # Render vhost -> Caddyfile blok
  vhostToBlock = name: v: ''
    ${name} {
      reverse_proxy ${v.upstream}
      ${optionalString (v.extraConfig or "" != "") v.extraConfig}
    }
  '';

  caddyfileText =
    concatStringsSep "\n\n" (mapAttrsToList vhostToBlock cfg.virtualHosts);

  composeDir = "/etc/compose/${cfg.stackName}";
  # Op NixOS is /etc/caddy een symlink → mount één bestand om symlinkgedoe te vermijden:
  caddyFileHost = "/etc/static/caddy/Caddyfile";
  dataDir       = cfg.dataDir;
  composeYml    = "${composeDir}/compose.yml";
in
{
  options.modules.caddyCompose = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Caddy managed via Podman Compose.";
    };

    stackName = mkOption {
      type = types.str;
      default = "caddy";
      description = "Compose stack/service name.";
    };

    image = mkOption {
      type = types.str;
      default = "docker.io/caddy:2";
      description = "Caddy container image.";
    };

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "ACME/Let's Encrypt contact email (CADDY_EMAIL).";
    };

    useHostNetwork = mkOption {
      type = types.bool;
      default = true;
      description = "Use host networking instead of explicit port mappings.";
    };

    ports = mkOption {
      type = types.listOf types.str;
      default = [ "80:80" "443:443" ];
      description = "Port mappings when host networking is disabled.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open TCP ports 80 and 443 in the firewall.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/caddy";
      description = "Directory for ACME storage (/data) and runtime config (/config).";
    };

    virtualHosts = mkOption {
      type = types.attrsOf (types.submodule ({ ... }: {
        options = {
          upstream = mkOption {
            type = types.str;
            description = "Reverse proxy upstream (e.g. http://host:port or https://host:port).";
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Extra Caddy directives for this vhost.";
          };
        };
      }));
      default = { };
      description = "Map of hostname -> vhost config (rendered into Caddyfile).";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables passed to the Caddy container.";
    };

    extraVolumes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional volume mounts for the Caddy container.";
    };

    serviceOverrides = mkOption {
      type = types.attrs;
      default = { };
      description = "Arbitrary docker-compose service fields to merge (advanced).";
      example = lib.literalExpression ''{ mem_limit = "512m"; }'';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      virtualisation.podman.enable = true;
      environment.systemPackages = [ pkgs.podman pkgs.podman-compose ];

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [ 80 443 ];
      };

      # Declaratieve bestanden
      environment.etc = {
        "caddy/Caddyfile".text = caddyfileText;

        "${"compose/" + cfg.stackName + "/compose.yml"}".text =
          let
            # Mount 1 bestand i.p.v. de hele map (lost NixOS symlink naar /nix/store op)
            volumes = [
              "${caddyFileHost}:/etc/caddy/Caddyfile:ro"
              "${dataDir}:/data"
              "${dataDir}:/config"
            ] ++ cfg.extraVolumes;

            envAttrs =
              cfg.environment //
              (lib.optionalAttrs (cfg.email != null) { CADDY_EMAIL = cfg.email; });

            serviceBase = {
              image = cfg.image;
              volumes = volumes;
              restart = "unless-stopped";
            };

            service =
              serviceBase
              // (if cfg.useHostNetwork then { network_mode = "host"; } else { ports = cfg.ports; })
              // (if envAttrs == {} then {} else { environment = envAttrs; })
              // cfg.serviceOverrides;

            composeObj = {
              version = "3.9";
              services."${cfg.stackName}" = service;
            };
          in
          lib.generators.toYAML {} composeObj;
      };

      # Zorg dat /var/lib/caddy bestaat
      systemd.tmpfiles.rules = [ "d ${dataDir} 0750 root root -" ];

      # Podman Compose service
      systemd.services."podman-compose@${cfg.stackName}" = {
        description = "Podman Compose stack: ${cfg.stackName}";
        after = [ "network-online.target" "tailscaled.service" "local-fs.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${composeDir}";
          Environment = "PATH=/run/current-system/sw/bin";

          # Start alleen als het host-bestand bestaat
          ExecStartPre = "/run/current-system/sw/bin/test -f ${caddyFileHost}";

          ExecStart = "${pkgs.podman-compose}/bin/podman-compose -f ${composeYml} up -d";
          ExecStop  = "${pkgs.podman-compose}/bin/podman-compose -f ${composeYml} down";
          TimeoutStartSec = 0;
        };
        wantedBy = [ "multi-user.target" ];
      };
    }
  ]);
}

