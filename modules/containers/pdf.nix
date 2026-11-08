
{ config, lib, ... }:

let
  cfg = config.apps.pdf;
in
{
  imports = [
    (import ./common.nix {
      name = "pdf";

      image = "docker.stirlingpdf.com/stirlingtools/stirling-pdf:3.2.2@sha256:c6872dd056b0046a14c5de1e9970283e7f1e1ff685bb08090c6b37a231127d31";

      port = 8080;
      bindAddress = "0.0.0.0";

      tailscaleDefault = true;

      mountConfig = false;
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = [
        "/var/lib/stirling-pdf/configs:/configs"
        "/var/lib/stirling-pdf/logs:/logs"
        "/var/lib/stirling-pdf/pipeline:/pipeline"
        "/var/lib/stirling-pdf/tessdata:/usr/share/tessdata"
      ];

      environment = {
        SYSTEM_DEFAULTLOCALE = "nl_NL";
      };
    })
  ];

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/stirling-pdf 0755 root root -"
      "d /var/lib/stirling-pdf/configs 0755 root root -"
      "d /var/lib/stirling-pdf/logs 0755 root root -"
      "d /var/lib/stirling-pdf/pipeline 0755 root root -"
      "d /var/lib/stirling-pdf/tessdata 0755 root root -"
    ];
  };
}
