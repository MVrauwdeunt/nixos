{ config, lib, ... }:

let
  cfg = config.asgard.security.crowdsec;
in
{
  options.asgard.security.crowdsec = {
    enable = lib.mkEnableOption "CrowdSec protection";

    firewallBouncer = lib.mkEnableOption
      "CrowdSec firewall remediation";
  };

  config = lib.mkIf cfg.enable {
    services.crowdsec = {
      enable = true;
      openFirewall = false;
      autoUpdateService = true;

      hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/sshd"
      ];

      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [
            "_SYSTEMD_UNIT=sshd.service"
          ];
          labels.type = "syslog";
        }
      ];
    };

    services.crowdsec-firewall-bouncer = {
      enable = cfg.firewallBouncer;
    };
  };
}