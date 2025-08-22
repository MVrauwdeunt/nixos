{ config, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.containers.authelia;
in {
  options.containers.authelia = {
    enable = mkOption { type = types.bool; default = false; };
    image  = mkOption { type = types.str; default = "ghcr.io/authelia/authelia:latest"; };
    configDir = mkOption { type = types.path; default = "/etc/authelia"; };  # bevat config.yml
    stateDir  = mkOption { type = types.path; default = "/var/lib/authelia"; };
    environment = mkOption { type = types.attrsOf types.str; default = { TZ = "Europe/Amsterdam"; }; };
  };

  config = mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # Zorg dat dirs bestaan (config/state)
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 root root -"
      "d ${cfg.configDir} 0750 root root -"
    ];

    virtualisation.oci-containers.containers.authelia = {
      image = cfg.image;
      extraOptions = [ "--network=host" ];
      environment = cfg.environment;
      volumes = [
        "${cfg.configDir}:/config:ro"    # /config/config.yml
        "${cfg.stateDir}:/var/lib/authelia"
      ];
      cmd = [ "--config" "/config/config.yml" ];
    };
  };
}
