
# modules/containers/caddy.nix
{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkOption
    types
    optionalString
    concatStringsSep
    mapAttrsToList;

  cfg = config.apps.caddy;

  # Dedicated non-root container identity
  caddyUid = 991;
  caddyGid = 991;

  vhostToBlock = name: v: ''
    ${name} {
      reverse_proxy ${v.upstream} {
        ${v.proxyExtraConfig}
      }
      ${optionalString (v.extraConfig != "") v.extraConfig}
    }
  '';

  caddyfileText = ''
    {
      log {
        format filter {
          request>headers>X-Api-Key delete
          request>headers>Authorization delete
          request>headers>Proxy-Authorization delete
          request>headers>Cookie delete
        }
      }
    }

    ${concatStringsSep "\n\n"
      (mapAttrsToList vhostToBlock cfg.virtualHosts)}
  '';

  # Immutable Caddyfile in the Nix store
  caddyfileStorePath =
    pkgs.writeText "Caddyfile" caddyfileText;

  dataDir = cfg.dataDir;

in
{
  options.apps.caddy = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    image = mkOption {
      type = types.str;
      default = "docker.io/caddy:2";
    };

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/caddy";
    };

    virtualHosts = mkOption {
      type = types.attrsOf
        (types.submodule ({ ... }: {
          options = {
            upstream = mkOption {
              type = types.str;
            };

            extraConfig = mkOption {
              type = types.lines;
              default = "";
            };

            proxyExtraConfig = mkOption {
              type = types.lines;
              default = "";
            };
          };
        }));

      default = { };
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
    };

    extraVolumes = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # Dedicated system group
    users.groups.caddy = {
      gid = caddyGid;
    };

    # Dedicated system user
    users.users.caddy = {
      isSystemUser = true;
      uid = caddyUid;
      group = "caddy";
      home = dataDir;
      createHome = false;
      description = "Caddy reverse proxy";
    };

    # Host-side reference for inspection
    environment.etc."caddy/Caddyfile".source =
      caddyfileStorePath;

    # Restart when generated Caddyfile changes
    systemd.services.podman-caddy.restartTriggers = [
      caddyfileStorePath
    ];

    # Persistent Caddy storage owned by dedicated user
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 caddy caddy -"
    ];

    # Existing firewall behavior - unchanged
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 80 443 ];
    };

    virtualisation.oci-containers.containers.caddy = {
      image = cfg.image;
      pull = "missing";

      extraOptions = [
        # Existing networking - unchanged
        "--network=host"
        "--dns=100.100.100.100"

        # Prevent privilege escalation
        "--security-opt=no-new-privileges"

        # Remove all default capabilities
        "--cap-drop=ALL"

        # Allow binding to privileged ports
        "--cap-add=NET_BIND_SERVICE"

        # Read-only container root filesystem
        "--read-only"

        # Writable temporary filesystem
        "--tmpfs=/tmp:rw,nosuid,nodev,size=32m"

        # Run as dedicated non-root user
        "--user=${toString caddyUid}:${toString caddyGid}"
      ];

      environment =
        cfg.environment
        // lib.optionalAttrs (cfg.email != null) {
          CADDY_EMAIL = cfg.email;
        };

      # Existing persistent volumes - unchanged
      volumes = [
        "${caddyfileStorePath}:/etc/caddy/Caddyfile:ro"
        "${dataDir}:/data"
        "${dataDir}:/config"
      ] ++ cfg.extraVolumes;
    };
  };
}

