{ pkgs, ... }:
{
  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services on sif";
    after = [
      "network-online.target"
      "tailscaled.service"
      "podman-netalertx.service"
      "unifi.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "podman-netalertx.service"
      "unifi.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -eu

      # Wait until tailscale is fully available
      for i in $(seq 1 30); do
        if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Clear existing service definitions to avoid stale configs
      ${pkgs.tailscale}/bin/tailscale serve clear svc:unifi || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:netalertx || true

      # Configure UniFi service (self-signed HTTPS backend)
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:unifi \
        --https=443 \
        https+insecure://127.0.0.1:8443

      # Configure NetAlertX service (HTTP backend)
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:netalertx \
        --https=443 \
        http://127.0.0.1:20211
    '';
  };
}
