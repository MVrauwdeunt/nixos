
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
      SLSKD_IP=""
      for attempt in $(seq 1 45); do
        SLSKD_IP=$(
          ${pkgs.podman}/bin/podman container inspect slskd 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r '[.[0].NetworkSettings.Networks // {} | to_entries[] | .value.IPAddress // empty] | first // empty' \
            2>/dev/null || true
        )
        if [[ "$SLSKD_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          break
        fi
        sleep 2
      done

      if [[ ! "$SLSKD_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: slskd has no Podman IPv4 after 90 seconds; refusing to start Soulseek forwarding" >&2
        exit 1
      fi

      echo "Forwarding Soulseek port ${soulseekPort} to slskd at $SLSKD_IP"
      ${pkgs.podman}/bin/podman exec gluetun sh -c \
        'apk add --no-cache socat >/dev/null 2>&1 || command -v socat >/dev/null'
      ${pkgs.podman}/bin/podman exec -d gluetun sh -c "
        pkill socat || true
        exec socat TCP-LISTEN:${soulseekPort},bind=${wireguardAddress},fork,reuseaddr TCP:$SLSKD_IP:${soulseekPort}
      "
    '';

    virtualisation.oci-containers.containers.gluetun = {
      image = "docker.io/qmcgaw/gluetun:latest@sha256:c2ee4191762fca6b6a3c3359a731198a95d9c9af4db32d466e223bf3a84e779b";
      pull = "missing";

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
