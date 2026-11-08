
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.gluetun;
  soulseekPort = "31481";
  wireguardAddress = "10.161.225.183";
in
{
  imports = [
    (import ./common.nix {
      name = "gluetun";
      image = "docker.io/qmcgaw/gluetun:v3.41.3@sha256:fa19cc76b2af13d57a8d3dc3066f2ada061b1c761b8aecf989b3877c0486e027";

      port = 8000;
      bindAddress = "0.0.0.0";
      configMount = "/gluetun";

      directoryOwner = "root";
      directoryGroup = "root";

      usePuidPgid = false;
      disableHealthcheck = false;

      extraVolumes = [
        "/run/secrets:/run/secrets:ro"
      ];

      environment = {
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
      ];
    })
  ];

  options.apps.gluetun.airvpnEnvSecretName = lib.mkOption {
    type = lib.types.str;
    default = "mimir/gluetun/airvpn_env";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.${cfg.airvpnEnvSecretName} = {
      sopsFile = ../../secrets.yaml;
      path = "${cfg.dataDir}/airvpn.env";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    virtualisation.oci-containers.containers.gluetun.environmentFiles = [
      config.sops.secrets.${cfg.airvpnEnvSecretName}.path
      config.sops.secrets."mimir/gluetun/control_env".path
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
        echo "ERROR: slskd has no Podman IPv4" >&2
        exit 1
      fi

      SOCAT_READY=0

      for attempt in $(seq 1 30); do
        if ${pkgs.podman}/bin/podman exec gluetun sh -c \
          'command -v socat >/dev/null 2>&1 || apk add --no-cache socat'; then
          SOCAT_READY=1
          break
        fi

        echo "Waiting for Gluetun connectivity (attempt $attempt/30)"
        sleep 3
      done

      if [ "$SOCAT_READY" -ne 1 ]; then
        echo "ERROR: socat unavailable in Gluetun" >&2
        exit 1
      fi

      echo "Forwarding Soulseek port ${soulseekPort} to slskd at $SLSKD_IP"

      ${pkgs.podman}/bin/podman exec -d gluetun sh -c "
        pkill socat || true
        exec socat TCP-LISTEN:${soulseekPort},bind=${wireguardAddress},fork,reuseaddr TCP:$SLSKD_IP:${soulseekPort}
      "
    '';
  };
}
