{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption types optionalString concatStringsSep mapAttrsToList;
  cfg = config.apps.caddy;

  vhostToBlock = name: v: ''
    ${name} {
      reverse_proxy ${v.upstream}
      ${optionalString (v.extraConfig or "" != "") v.extraConfig}
    }
  '';
  caddyfileText =
    concatStringsSep "\n\n" (mapAttrsToList vhostToBlock cfg.virtualHosts);

  caddyfilePath = "/etc/caddy/Caddyfile";
  dataDir       = cfg.dataDir;
in {
  options.apps.caddy = {
    enable = mkOption { type = types.bool; default = false; };
    image  = mkOption { type = types.str; default = "docker.io/caddy:2"; };
    email  = mkOption { type = types.nullOr types.str; default = null; };
    openFirewall = mkOption { type = types.bool; default = true; };
    dataDir = mkOption { type = types.path; default = "/var/lib/caddy"; };
    virtualHosts = mkOption {
      type = types.attrsOf (types.submodule ({ ... }: {
        options = {
          upstream = mkOption { type = types.str; };
          extraConfig = mkOption { type = types.lines; default = ""; };
        };
      }));
      default = { };
    };
    environment = mkOption { type = types.attrsOf types.str; default = { }; };
    extraVolumes = mkOption { type = types.listOf types.str; default = [ ]; };
  };

  config = mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # Caddyfile renderen
    environment.etc."caddy/Caddyfile".text = caddyfileText;

    # Data dir aanwezig
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 root root -"
    ];

    # Firewall
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 80 443 ];
    };

    # Caddy container (systemd: container-caddy.service)
    virtualisation.oci-containers.containers.caddy = {
      image = cfg.image;
      extraOptions = [ "--network=host" ];
      environment = cfg.environment //
        (lib.optionalAttrs (cfg.email != null) { CADDY_EMAIL = cfg.email; });
      volumes = [
        "${caddyfilePath}:/etc/caddy/Caddyfile:ro"
        "${dataDir}:/data"
        "${dataDir}:/config"
      ] ++ cfg.extraVolumes;
      # (optioneel) healthcheck/command hier toevoegen indien gewenst
    };
  };
}
