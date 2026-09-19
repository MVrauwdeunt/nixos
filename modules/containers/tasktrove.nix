{ config, lib, ... }:

let
  cfg = config.apps.tasktrove;
in
{
  options.apps.tasktrove = {
    enable = lib.mkEnableOption "TaskTrove";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3002;
      description = "Local TaskTrove web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose TaskTrove through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/tasktrove 0755 root root -"
      "d /var/lib/tasktrove/data 0755 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.tasktrove = {
      image = "ghcr.io/dohsimpson/tasktrove:latest";
      pull = "always";
      
      ports = [
        "127.0.0.1:${toString cfg.port}:3000"
      ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Europe/Amsterdam";
      };

      volumes = [
        "/var/lib/tasktrove/data:/app/data"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}