
{ config, lib, pkgs, ... }:

let
  # ------------------------------------------------------------
  # Containerized applications
  # ------------------------------------------------------------

  exposedApps =
    builtins.filter
      (name:
        (config.apps.${name}.enable or false)
        && (config.apps.${name}.tailscale.enable or false)
        && (config.apps.${name} ? port)
      )
      (builtins.attrNames config.apps);

  # ------------------------------------------------------------
  # Local system services
  # ------------------------------------------------------------

  # Non-Podman services use the same Tailscale Services manager
  # as containerized applications.

  exposedLocalServices =
    lib.filterAttrs
      (_: service: service.enable)
      config.my.tailscaleServices.local;

  localNames = builtins.attrNames exposedLocalServices;

  # ------------------------------------------------------------
  # Systemd dependencies
  # ------------------------------------------------------------

  podmanUnits =
    map (name: "podman-${name}.service") exposedApps;

  localUnits =
    lib.concatMap
      (name:
        let
          unit = exposedLocalServices.${name}.systemdUnit;
        in
          lib.optional (unit != null) unit
      )
      localNames;

  # ------------------------------------------------------------
  # Clear managed Tailscale Services
  # ------------------------------------------------------------

  clearCommands = lib.concatStringsSep "\n" [
    (lib.concatMapStringsSep "\n" (name:
      let
        serviceName =
          config.apps.${name}.tailscale.serviceName or name;
      in ''
        ${pkgs.tailscale}/bin/tailscale serve clear \
          svc:${serviceName} || true
      ''
    ) exposedApps)

    (lib.concatMapStringsSep "\n" (name:
      let
        serviceName =
          exposedLocalServices.${name}.serviceName;
      in ''
        ${pkgs.tailscale}/bin/tailscale serve clear \
          svc:${serviceName} || true
      ''
    ) localNames)
  ];

  # ------------------------------------------------------------
  # HTTPS services
  # ------------------------------------------------------------

  httpCommands = lib.concatStringsSep "\n" [
    (lib.concatMapStringsSep "\n" (name:
      let
        scheme =
          config.apps.${name}.tailscale.scheme or "http";

        port =
          toString config.apps.${name}.port;

        serviceName =
          config.apps.${name}.tailscale.serviceName or name;
      in ''
        # ${name} HTTPS
        ${pkgs.tailscale}/bin/tailscale serve \
          --service=svc:${serviceName} \
          --https=443 \
          ${scheme}://127.0.0.1:${port}
      ''
    ) exposedApps)

    (lib.concatMapStringsSep "\n" (name:
      let
        service = exposedLocalServices.${name};
        port = toString service.port;
      in ''
        # ${name} HTTPS
        ${pkgs.tailscale}/bin/tailscale serve \
          --service=svc:${service.serviceName} \
          --https=443 \
          ${service.scheme}://127.0.0.1:${port}
      ''
    ) localNames)
  ];

  # ------------------------------------------------------------
  # TCP services
  # ------------------------------------------------------------

  tcpCommands =
    lib.concatMapStringsSep "\n" (name:
      let
        tcpPorts =
          config.apps.${name}.tailscale.tcpPorts or [];

        serviceName =
          config.apps.${name}.tailscale.serviceName or name;
      in
        lib.concatMapStringsSep "\n" (port: ''
          # ${name} TCP ${toString port}
          ${pkgs.tailscale}/bin/tailscale serve \
            --service=svc:${serviceName} \
            --tcp=${toString port} \
            tcp://127.0.0.1:${toString port}
        '') tcpPorts
    ) exposedApps;

in
{
  # ------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------

  options.my.tailscaleServices.local = lib.mkOption {
    default = {};

    description =
      "Local non-Podman backends managed as Tailscale Services.";

    type = lib.types.attrsOf (
      lib.types.submodule ({ name, ... }: {
        options = {
          enable =
            lib.mkEnableOption "Tailscale Service for ${name}";

          serviceName = lib.mkOption {
            type = lib.types.str;
            default = name;

            description =
              "Tailscale Service name without the svc: prefix.";
          };

          port = lib.mkOption {
            type = lib.types.port;

            description =
              "Local loopback port for this service.";
          };

          scheme = lib.mkOption {
            type = lib.types.enum [
              "http"
              "https"
            ];

            default = "http";
          };

          systemdUnit = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;

            description =
              "Systemd unit that serves the local endpoint.";
          };
        };
      })
    );
  };

  # ------------------------------------------------------------
  # NixOS configuration
  # ------------------------------------------------------------

  config = {

    # ----------------------------------------------------------
    # Tailscale daemon
    # ----------------------------------------------------------

    # Keep tailscaled running during NixOS switches.
    # deploy-rs connects over Tailscale, so a restart could
    # interrupt an active deployment.

    systemd.services.tailscaled.restartIfChanged = false;

    # ----------------------------------------------------------
    # Tailscale Services manager
    # ----------------------------------------------------------

    systemd.services.tailscale-services = {
      description = "Configure Tailscale Services";

      after = [
        "network-online.target"
        "tailscaled.service"
      ] ++ podmanUnits ++ localUnits;

      wants = [
        "network-online.target"
        "tailscaled.service"
      ] ++ podmanUnits ++ localUnits;

      wantedBy = [
        "multi-user.target"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -eu

        # Wait for Tailscale to become available.
        for i in $(seq 1 30); do
          if ${pkgs.tailscale}/bin/tailscale status \
            >/dev/null 2>&1; then
            break
          fi

          sleep 2
        done

        # Clear only services managed by this module.
        ${clearCommands}

        # Configure HTTPS services.
        ${httpCommands}

        # Configure TCP services.
        ${tcpCommands}
      '';
    };
  };
}
