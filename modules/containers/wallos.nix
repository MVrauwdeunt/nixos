{ config, lib, ... }:

let
  cfg = config.apps.wallos;
in
{
  options.apps.wallos = {
    enable = lib.mkEnableOption "Wallos subscription tracker";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/bellamy/wallos:latest";
      description = "Wallos container image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wallos";
      description = "Persistent Wallos data directory.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8282;
      description = "Local HTTP port for Wallos.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Wallos port in the host firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Wallos through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/db 0755 root root -"
      "d ${cfg.dataDir}/logos 0755 root root -"
    ];

    virtualisation.oci-containers.containers.wallos = {
      image = cfg.image;
      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:80"
      ];

      volumes = [
        "${cfg.dataDir}/db:/var/www/html/db"
        "${cfg.dataDir}/logos:/var/www/html/images/uploads/logos"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}