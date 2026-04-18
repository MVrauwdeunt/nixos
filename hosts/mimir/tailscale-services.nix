{ pkgs, ... }:
{
  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services on mimir";
    after = [
      "network-online.target"
      "tailscaled.service"
      "podman-jellyfin.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "podman-jellyfin.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -eu

      # Wait until Tailscale is fully available
      for i in $(seq 1 30); do
        if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Clear existing service definition to avoid stale config
      ${pkgs.tailscale}/bin/tailscale serve clear svc:jellyfin || true

      # Configure Jellyfin service (HTTP backend)
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:jellyfin \
        --https=443 \
        http://127.0.0.1:8096
    '';
  };
}
