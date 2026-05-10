{ config, lib, pkgs, ... }:

let
  exposedApps =
    builtins.filter
      (name:
        (config.apps.${name}.enable or false)
        && (config.apps.${name}.tailscale.enable or false)
        && (config.apps.${name} ? port)
      )
      (builtins.attrNames config.apps);

  podmanUnits =
    map (name: "podman-${name}.service") exposedApps;

  clearCommands =
    lib.concatMapStringsSep "\n" (name: ''
      ${pkgs.tailscale}/bin/tailscale serve clear svc:${name} || true
    '') exposedApps;

  httpCommands =
    lib.concatMapStringsSep "\n" (name:
      let
        scheme = config.apps.${name}.tailscale.scheme or "http";
        port = toString config.apps.${name}.port;
      in ''
        # ${name} https
        ${pkgs.tailscale}/bin/tailscale serve \
          --service=svc:${name} \
          --https=443 \
          ${scheme}://127.0.0.1:${port}
      ''
    ) exposedApps;

  tcpCommands =
    lib.concatMapStringsSep "\n" (name:
      let
        tcpPorts = config.apps.${name}.tailscale.tcpPorts or [];
      in
        lib.concatMapStringsSep "\n" (port: ''
          # ${name} tcp ${toString port}
          ${pkgs.tailscale}/bin/tailscale serve \
            --service=svc:${name} \
            --tcp=${toString port} \
            tcp://127.0.0.1:${toString port}
        '') tcpPorts
    ) exposedApps;
in
{
  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services";

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

      # Configure HTTPS services
      ${httpCommands}

      # Configure TCP services
      ${tcpCommands}
    '';
  };
}