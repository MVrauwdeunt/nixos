{ pkgs, ... }:
{
  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services on mimir";
    after = [
      "network-online.target"
      "tailscaled.service"
      "podman-jellyfin.service"
      "podman-seerr.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "podman-jellyfin.service"
      "podman-seerr.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -eu

      for i in $(seq 1 30); do
        if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      ${pkgs.tailscale}/bin/tailscale serve clear svc:jellyfin || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:seerr || true

      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:jellyfin \
        --https=443 \
        http://127.0.0.1:8096

      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:seerr \
        --https=443 \
        http://127.0.0.1:5055
    '';
  };
}
