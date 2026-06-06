{ config, lib, ... }:

let
  cfg = config.apps.gluetun;
in
{
  options.apps.gluetun = {
    enable = lib.mkEnableOption "Gluetun VPN container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gluetun";
    };

    airvpnEnvSecretName = lib.mkOption {
      type = lib.types.str;
      default = "mimir/gluetun/airvpn_env";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.${cfg.airvpnEnvSecretName} = {
      sopsFile = ../../secrets.yaml;
      path = "${cfg.dataDir}/airvpn.env";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    virtualisation.oci-containers.containers.gluetun = {
      image = "docker.io/qmcgaw/gluetun:latest";

      volumes = [
        "${cfg.dataDir}:/gluetun"
      ];

      environmentFiles = [
        config.sops.secrets.${cfg.airvpnEnvSecretName}.path
      ];

      environment = {
        TZ = "Europe/Amsterdam";

        VPN_SERVICE_PROVIDER = "airvpn";
        VPN_TYPE = "wireguard";

        WIREGUARD_ADDRESSES = "10.161.225.183/32";

        SERVER_COUNTRIES = "Switzerland,Romania";

        FIREWALL_VPN_INPUT_PORTS = "31481";
      };

      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=bridge"
      ];
    };
  };
}