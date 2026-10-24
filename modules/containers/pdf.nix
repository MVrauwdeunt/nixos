
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
      image = "docker.stirlingpdf.com/stirlingtools/stirling-pdf@sha256:10164ffe04961b02ebc9fa4da12064eeacb8d3bc3e09ceb059f78ce7aaa83207";
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
