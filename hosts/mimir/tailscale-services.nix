{ pkgs, ... }:
{
  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services on mimir";

    after = [
      "network-online.target"
      "tailscaled.service"
      "podman-jellyfin.service"
      "podman-seerr.service"
      "podman-prowlarr.service"
      "podman-radarr.service"
      "podman-sonarr.service"
      "podman-bazarr.service"
      "podman-lidarr.service"
    ];

    wants = [
      "network-online.target"
      "tailscaled.service"
      "podman-jellyfin.service"
      "podman-seerr.service"
      "podman-prowlarr.service"
      "podman-radarr.service"
      "podman-sonarr.service"
      "podman-bazarr.service"
      "podman-lidarr.service"
    ];

    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -eu

      # Wait for Tailscale
      for i in $(seq 1 30); do
        if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Clear existing services
      ${pkgs.tailscale}/bin/tailscale serve clear svc:jellyfin || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:seerr || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:prowlarr || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:radarr || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:sonarr || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:bazarr || true
      ${pkgs.tailscale}/bin/tailscale serve clear svc:lidarr || true

      # Jellyfin
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:jellyfin \
        --https=443 \
        http://127.0.0.1:8096

      # Seerr
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:seerr \
        --https=443 \
        http://127.0.0.1:5055

      # Prowlarr
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:prowlarr \
        --https=443 \
        http://127.0.0.1:9696

      # Radarr
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:radarr \
        --https=443 \
        http://127.0.0.1:7878

      # Sonarr
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:sonarr \
        --https=443 \
        http://127.0.0.1:8989

      # Bazarr
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:bazarr \
        --https=443 \
        http://127.0.0.1:6767

      # Lidarr
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:lidarr \
        --https=443 \
        http://127.0.0.1:8686
    '';
  };
}
