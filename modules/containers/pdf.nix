
{ config, lib, ... }:

let
  cfg = config.apps.pdf;
in
{
  options.apps.pdf = {
    enable = lib.mkEnableOption "Stirling PDF";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.pdf = {
      image = "docker.stirlingpdf.com/stirlingtools/stirling-pdf:3.2.1@sha256:f95b691c3df463373258e21a578b404f1eb4c7660e8170a40e3e03c9c8f208a4";
      pull = "missing";

      ports = [
        "${toString cfg.port}:8080"
      ];

      volumes = [
        "/var/lib/stirling-pdf/configs:/configs"
        "/var/lib/stirling-pdf/logs:/logs"
        "/var/lib/stirling-pdf/pipeline:/pipeline"
        "/var/lib/stirling-pdf/tessdata:/usr/share/tessdata"
      ];

      environment = {
        SYSTEM_DEFAULTLOCALE = "nl_NL";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/stirling-pdf 0755 root root -"
      "d /var/lib/stirling-pdf/configs 0755 root root -"
      "d /var/lib/stirling-pdf/logs 0755 root root -"
      "d /var/lib/stirling-pdf/pipeline 0755 root root -"
      "d /var/lib/stirling-pdf/tessdata 0755 root root -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
