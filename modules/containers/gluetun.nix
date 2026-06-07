{ config, lib, pkgs, ... }:

let
  cfg = config.apps.gluetun;

  soulseekPort = "31481";
  wireguardAddress = "10.161.225.183";
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

    systemd.services.podman-gluetun.postStart = lib.mkAfter ''
      sleep 8

      SLSKD_IP=$(${pkgs.podman}/bin/podman inspect slskd --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

      ${pkgs.podman}/bin/podman exec -d gluetun sh -c "
        apk add --no-cache socat >/dev/null 2>&1 || true
        pkill socat || true
        socat TCP-LISTEN:${soulseekPort},bind=${wireguardAddress},fork,reuseaddr TCP:$SLSKD_IP:${soulseekPort}
      "
    '';

    virtualisation.oci-containers.containers.gluetun = {
      image = "docker.io/qmcgaw/gluetun:latest";

      ports = [
        "8000:8000"
      ];

      volumes = [
        "${cfg.dataDir}:/gluetun"
        "/run/secrets:/run/secrets:ro"
      ];

      environmentFiles = [
        config.sops.secrets.${cfg.airvpnEnvSecretName}.path
        config.sops.secrets."mimir/gluetun/control_env".path
      ];

      environment = {
        TZ = "Europe/Amsterdam";

        VPN_SERVICE_PROVIDER = "airvpn";
        VPN_TYPE = "wireguard";

        WIREGUARD_ADDRESSES = "${wireguardAddress}/32";

        SERVER_COUNTRIES = "Switzerland,Romania";

        FIREWALL_VPN_INPUT_PORTS = soulseekPort;

        GLUETUN_HTTP_CONTROL_SERVER_ENABLE = "on";
      };

      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=bridge"
      ];
    };
  };
}