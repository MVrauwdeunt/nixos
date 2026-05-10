{ config, lib, pkgs, ... }:

let
  exposedApps =
    builtins.filter
      (name:
        config.apps.${name}.enable
        && config.apps.${name}.tailscale.enable
      )
      (builtins.attrNames config.apps);

  podmanUnits =
    map (name: "podman-${name}.service") exposedApps;

  clearCommands =
    lib.concatMapStringsSep "\n" (name: ''
      ${pkgs.tailscale}/bin/tailscale serve clear svc:${name} || true
    '') exposedApps;

  serveCommands =
    lib.concatMapStringsSep "\n" (name: ''
      # ${name}
      ${pkgs.tailscale}/bin/tailscale serve \
        --service=svc:${name} \
        --https=443 \
        http://127.0.0.1:${toString config.apps.${name}.port}
    '') exposedApps;

in
{
  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services on mimir";

    after = [
      "network-online.target"
      "tailscaled.service"
    ] ++ podmanUnits;

    wants = [
      "network-online.target"
      "tailscaled.service"
    ] ++ podmanUnits;

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
      ${clearCommands}

      # Configure services
      ${serveCommands}
    '';
  };
}