{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge mkOption types concatStringsSep mapAttrsToList optionalString literalExpression;

  cfg = config.modules.caddyCompose;

  # Eén vhost-blok renderen
  vhostToBlock = name: v:
    ''
    ${name} {
      reverse_proxy ${v.upstream}
      ${optionalString (v.extraConfig or "" != "") v.extraConfig}
    }
    '';

  caddyfileText =
    concatStringsSep "\n\n" (mapAttrsToList vhostToBlock cfg.virtualHosts);

  composeDir   = "/etc/compose/${cfg.stackName}";
  caddyDir     = "/etc/caddy";
  dataDir      = cfg.dataDir;       # ACME storage & runtime
  composeYml   = "${composeDir}/compose.yml";
  caddyfile    = "${caddyDir}/Caddyfile";
in
{
  options.modules.caddyCompose = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Caddy managed by Podman Compose.";
    };

    # naam van de compose stack en service
    stackName = mkOption {
      type = types.str;
      default = "caddy";
      description = "Compose stack/service name (used by systemd template and /etc/compose path).";
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

    # Host networking is de simpelste manier voor 80/443 en ACME
    useHostNetwork = mkOption {
      type = types.bool;
      default = true;
      description = "Run container with host networking instead of mapping ports.";
    };

    ports = mkOption {
      type = types.listOf types.str;
      default = [ "80:80" "443:443" ];
      description = "Port mappings when not using host networking.";
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

    # Declaratieve vhosts
    virtualHosts = mkOption {
      type = types.attrsOf (types.submodule ({ ... }: {
        options = {
          upstream = mkOption {
            type = types.str;
            description = "Reverse proxy upstream URL (e.g., http://host:port or https://host:port).";
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Extra Caddy directives for this vhost (headers, timeouts, etc.).";
          };
        };
      }));
      default = { };
      description = "Map van hostnames -> upstream config.";
      example = literalExpression ''
        {
          "recipes.gladsheimr.nl" = {
            upstream = "http://mealie.gladsheimr.ts.net:9000";
            extraConfig = '''
              header {
                Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
              }
            ''';
          };
        }
      '';
    };

    # Extra environment voor de container
    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables for the Caddy container.";
    };

    # Extra volumes (naast Caddyfile + data/config)
    extraVolumes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional volume mounts for the Caddy container.";
    };

    # Extra compose service-keys (als je iets speciaals wilt toevoegen)
    extraCompose = mkOption {
      type = types.lines;
      default = "";
      description = "Raw YAML fragment appended under the caddy service in compose.yml.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Open poorten indien gewenst
      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 80 443 ];

      # Bestanden: Caddyfile & Compose
      environment.etc = {
        # "${builtins.baseNameOf caddyfile}".source = caddyfile;
        # NB: we schrijven de content hieronder in .text (zelfde pad)
        "caddy/Caddyfile".text = caddyfileText;

        "${"compose/" + cfg.stackName + "/compose.yml"}".text =
          let
            portsYaml = if cfg.useHostNetwork then "" else ''
              ports:
              ${concatStringsSep "\n" (map (p: "      - \"${p}\"") cfg.ports)}
            '';

            networkModeYaml = if cfg.useHostNetwork then ''
              network_mode: host
            '' else "";

            volumesYaml = concatStringsSep "\n" ([
              "      - ${caddyDir}:/etc/caddy:ro"
              "      - ${dataDir}:/data"
              "      - ${dataDir}:/config"
            ] ++ cfg.extraVolumes);

            envYaml =
              concatStringsSep "\n"
                (map (k: "      - ${k}=${cfg.environment.${k}}")
                  (lib.attrNames cfg.environment))
              + (if cfg.email == null then "" else "\n      - CADDY_EMAIL=${cfg.email}");
          in
          ''
            version: "3.9"
            services:
              ${cfg.stackName}:
                image: ${cfg.image}
                ${networkModeYaml}${portsYaml}
                volumes:
                ${volumesYaml}
                environment:
                ${envYaml}
                restart: unless-stopped
            ${cfg.extraCompose}
          '';
      };

      # Directories
      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 root root -"
      ];

      # Templated systemd service: podman-compose@<stackName>
      systemd.services."podman-compose@${cfg.stackName}" = {
        description = "Podman Compose stack: ${cfg.stackName}";
        after = [ "network-online.target" "tailscaled.service" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${composeDir}";
          ExecStart = "${pkgs.podman-compose}/bin/podman-compose -f ${composeYml} up -d";
          ExecStop  = "${pkgs.podman-compose}/bin/podman-compose -f ${composeYml} down";
          TimeoutStartSec = 0;
        };
        wantedBy = [ "multi-user.target" ];
      };

      systemd.services."podman-compose@${cfg.stackName}".enable = true;

      # Zorg dat podman-compose beschikbaar is
      environment.systemPackages = [ pkgs.podman-compose ];
    }
  ]);
}

