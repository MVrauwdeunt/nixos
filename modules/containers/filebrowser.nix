{ config, lib, ... }:

let
  cfg = config.apps.filebrowser;
in
{
  options.apps.filebrowser = {
    enable = lib.mkEnableOption "File Browser";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Local File Browser web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose File Browser through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/filebrowser 0755 root root -"
      "d /var/lib/filebrowser/database 0755 1000 1000 -"
      "d /var/lib/filebrowser/config 0755 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.filebrowser = {
      image = "docker.io/filebrowser/filebrowser:latest";

      ports = [
        "127.0.0.1:${toString cfg.port}:80"
      ];

      environment = {
        PUID = "1000";
        PGID = "1000";
      };

      volumes = [
        "/mnt/Volume2:/srv"
        "/var/lib/filebrowser/database:/database"
        "/var/lib/filebrowser/config:/config"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}