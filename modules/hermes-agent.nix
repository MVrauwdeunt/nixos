
# modules/hermes-agent.nix
#
# Asgard Hermes Agent
#
# NYX    - Central intelligence / default profile
# WRAITH - Infrastructure and security
# VESPER - Finance
# LYRA   - Home Assistant and automation
# SYNTH  - Software engineering
# PULSE  - Health and performance
#
# Container: Podman on Vili
# Configuration: Declarative NixOS
# Secrets: SOPS
# Memory: Honcho
# Delegation: Advanced Delegation / Profile Routes

{ inputs, config, pkgs, lib, ... }:

let
  # ------------------------------------------------------------
  # Hermes package
  # ------------------------------------------------------------

  # Nix builds currently report Hermes version 0.0.0.
  # This override provides the version required by plugins
  # that enforce a minimum Hermes release.
  #
  # The upstream source remains pinned by flake.lock.

  hermesPackage =
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      version = "0.23.0";
    };

  pythonPackages = hermesPackage.python.pkgs;

  # ------------------------------------------------------------
  # Honcho source
  # ------------------------------------------------------------

  honchoSource = pkgs.fetchFromGitHub {
    owner = "plastic-labs";
    repo = "honcho";

    rev = "7dd3702933d5cc1ce1f0a44bba6525cc61ee6e16";

    hash = "sha256-NmThEGtoEX9HDWjAB6czuRSyf95lCeu/dkTONUM9thU=";
  };

  # ------------------------------------------------------------
  # Honcho plugin
  # ------------------------------------------------------------

  honchoPlugin = pkgs.runCommand "honcho-plugin" { } ''
    mkdir -p "$out"

    cp -r \
      ${honchoSource}/hermes-plugin-honcho/. \
      "$out/"
  '';

  # ------------------------------------------------------------
  # Honcho Python SDK
  # ------------------------------------------------------------

  honchoSdk = pythonPackages.buildPythonPackage {
    pname = "honcho-ai";
    version = "2.8.0";

    pyproject = true;

    src = honchoSource;
    sourceRoot = "${honchoSource.name}/sdks/python";

    build-system = [
      pythonPackages.setuptools
      pythonPackages.wheel
    ];

    pythonRemoveDeps = [
      "httpx"
      "pydantic"
      "certifi"
    ];

    doCheck = false;
  };

  # ------------------------------------------------------------
  # Advanced Delegation plugin
  # ------------------------------------------------------------

  # Official Hermes plugin from the pinned flake input.
  #
  # Installed only in the default Hermes home where NYX runs.
  # Target profiles do not need the delegation plugin installed.

  delegationPlugin =
    pkgs.runCommand "hermes-advanced-delegation" { } ''
      mkdir -p "$out"

      cp -r \
        ${inputs.hermes-official-plugins}/advanced-delegation/. \
        "$out/"
    '';

  # ------------------------------------------------------------
  # Hermes host CLI wrapper
  # ------------------------------------------------------------

  # Run Hermes inside the existing Podman container.
  #
  # The container runs with the Hermes service UID/GID.
  # Running the CLI directly as zanbee caused the
  # unsafe_control_path UID validation error.
  #
  # UID and GID are resolved dynamically.
  #
  # IMPORTANT:
  # Use the NixOS setuid sudo wrapper.
  # Do not use ${pkgs.sudo}/bin/sudo.

  hermesHostCli = pkgs.writeShellScriptBin "hermes" ''
    set -euo pipefail

    uid="$(${pkgs.coreutils}/bin/id -u hermes)"
    gid="$(${pkgs.coreutils}/bin/id -g hermes)"

    container="hermes-agent"
    hermes_bin="/data/current-package/bin/hermes"

    if [[ -t 0 && -t 1 ]]; then
      exec ${config.security.wrapperDir}/sudo \
        ${pkgs.podman}/bin/podman exec \
        -it \
        --user "$uid:$gid" \
        "$container" \
        "$hermes_bin" \
        "$@"
    else
      exec ${config.security.wrapperDir}/sudo \
        ${pkgs.podman}/bin/podman exec \
        -i \
        --user "$uid:$gid" \
        "$container" \
        "$hermes_bin" \
        "$@"
    fi
  '';

in
{
  # ------------------------------------------------------------
  # Module imports
  # ------------------------------------------------------------

  imports = [
    inputs.hermes-agent.nixosModules.default

    ./hermes/mcp
    ./hermes/profiles.nix
  ];

  # ------------------------------------------------------------
  # Container runtime
  # ------------------------------------------------------------

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.backend = "podman";

  # ------------------------------------------------------------
  # Host CLI
  # ------------------------------------------------------------

  # Install the container-aware wrapper instead of the
  # default Hermes host CLI.

  environment.systemPackages = [
    hermesHostCli
  ];

  # ------------------------------------------------------------
  # Filesystem permissions
  # ------------------------------------------------------------

  # Keep existing install lockfile permissions.
  #
  # Plugins are managed through extraPlugins.
  # No additional Honcho symlink via tmpfiles.

  systemd.tmpfiles.rules = [
    "z /var/lib/hermes/.hermes/installs/*/.install.lock 0660 hermes hermes -"
  ];

  # ------------------------------------------------------------
  # Legacy Honcho symlink cleanup
  # ------------------------------------------------------------

  # Remove only the legacy Honcho symlink pointing
  # directly to the old Nix plugin derivation.
  #
  # Does not delete memory, conversations or settings.

  system.activationScripts.hermesRemoveLegacyHonchoLink = {
    deps = [ "users" ];

    text = ''
      link="/var/lib/hermes/.hermes/plugins/honcho"

      if [ -L "$link" ]; then
        target="$(${pkgs.coreutils}/bin/readlink -- "$link")"

        case "$target" in
          /nix/store/*-honcho-plugin)
            echo "Hermes: removing legacy Honcho symlink"

            ${pkgs.coreutils}/bin/rm -- "$link"
            ;;
        esac
      fi
    '';
  };

  # ------------------------------------------------------------
  # Host filesystem permissions
  # ------------------------------------------------------------

  # Preserve existing permissions required for host access.
  #
  # No recursive chmod.
  # No modifications to secret file permissions.

  systemd.services.hermes-agent.preStart = lib.mkAfter ''
    hermes_home="/var/lib/hermes/.hermes"

    if [ -d "$hermes_home" ] && [ ! -L "$hermes_home" ]; then
      ${pkgs.coreutils}/bin/chmod g+x "$hermes_home"
    fi

    for dir in \
      "$hermes_home/plugins" \
      "$hermes_home/plugins/platforms"
    do
      if [ -d "$dir" ] && [ ! -L "$dir" ]; then
        ${pkgs.coreutils}/bin/chmod g+rx "$dir"
      fi
    done

    profiles_dir="$hermes_home/profiles"

    if [ -d "$profiles_dir" ] && [ ! -L "$profiles_dir" ]; then
      ${pkgs.coreutils}/bin/chmod g+rx "$profiles_dir"
    fi

    for agent in wraith vesper lyra synth pulse; do
      profile_dir="$profiles_dir/$agent"

      if [ -d "$profile_dir" ] && [ ! -L "$profile_dir" ]; then
        ${pkgs.coreutils}/bin/chmod g+x "$profile_dir"
      fi
    done
  '';

  # ------------------------------------------------------------
  # Hermes Agent
  # ------------------------------------------------------------

  services.hermes-agent = {
    enable = true;

    # Override Nix package version for plugin compatibility.
    package = hermesPackage;

    # Our own container CLI replaces the default host binary.
    addToSystemPackages = false;

    # ----------------------------------------------------------
    # Podman container
    # ----------------------------------------------------------

    container = {
      enable = true;

      backend = "podman";

      hostUsers = [
        "zanbee"
      ];

      image =
        "docker.io/library/ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54";
    };

    # ----------------------------------------------------------
    # SOPS-managed credentials
    # ----------------------------------------------------------

    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    # ----------------------------------------------------------
    # Declarative plugins
    # ----------------------------------------------------------

    extraPlugins = [
      honchoPlugin
      delegationPlugin
    ];

    extraPythonPackages = [
      honchoSdk
    ];

    # ----------------------------------------------------------
    # Honcho memory configuration
    # ----------------------------------------------------------

    hermesHomeFiles."honcho.json" = builtins.toJSON {
      baseUrl = "http://127.0.0.1:8000";

      hosts.hermes = {
        enabled = true;

        workspace = "hermes";

        aiPeer = "hermes";
        peerName = "michel";

        sessionStrategy = "global";
        pinUserPeer = true;

        recallMode = "hybrid";
        writeFrequency = "async";
      };
    };

    # ----------------------------------------------------------
    # Hermes settings
    # ----------------------------------------------------------

    settings = {
      # --------------------------------------------------------
      # Model
      # --------------------------------------------------------

      model = {
        provider = "openai-api";
        default = "gpt-5.4-mini";
        key_env = "OPENAI_API_KEY";
      };

      # --------------------------------------------------------
      # Memory
      # --------------------------------------------------------

      memory.provider = "honcho";

      # --------------------------------------------------------
      # Enabled plugins
      # --------------------------------------------------------

      plugins.enabled = [
        "honcho"
        "advanced-delegation"
      ];

      # --------------------------------------------------------
      # Webapp
      # --------------------------------------------------------

      # Publish through the existing Tailscale Services manager.
      # Keep the backend bound to loopback.
      webapp = {
        enabled = true;
        host = "127.0.0.1";
        port = 9120;
        public_url = "https://hermes.fiordland-gar.ts.net";
      };

      # --------------------------------------------------------
      # Profile delegation
      # --------------------------------------------------------

      # NYX receives all Signal messages.
      #
      # When a specialist is requested, delegate_task can
      # route the task into the matching Hermes profile.
      #
      # Each delegated profile uses its own:
      # - SOUL.md
      # - Model configuration
      # - Credentials
      # - Skills
      #
      # No default delegation profile is configured.
      # NYX handles general requests herself.

      delegation = {
        backend = "profile_routes";

        backends.profile_routes = {
          profiles = [
            {
              name = "wraith";
              description =
                "Infrastructure, Linux, NixOS, networking, Tailscale, servers and security.";
            }
            {
              name = "vesper";
              description =
                "Personal finances, Actual Budget, savings, debts and financial planning.";
            }
            {
              name = "lyra";
              description =
                "Home Assistant, smart home, lighting, climate, sensors and automation.";
            }
            {
              name = "synth";
              description =
                "Software development, programming, debugging, testing and code review.";
            }
            {
              name = "pulse";
              description =
                "Health, cycling, endurance training, performance, sleep and recovery.";
            }
          ];
        };
      };
    };
  };
}
