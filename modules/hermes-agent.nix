
{ inputs, config, pkgs, lib, ... }:

let
  pythonPackages =
    config.services.hermes-agent.package.python.pkgs;

  # Honcho source, pinned to a fixed revision.
  honchoSource = pkgs.fetchFromGitHub {
    owner = "plastic-labs";
    repo = "honcho";
    rev = "7dd3702933d5cc1ce1f0a44bba6525cc61ee6e16";
    hash = "sha256-NmThEGtoEX9HDWjAB6czuRSyf95lCeu/dkTONUM9thU=";
  };

  honchoPlugin = pkgs.runCommand "honcho-plugin" { } ''
    mkdir -p "$out"
    cp -r ${honchoSource}/hermes-plugin-honcho/. "$out/"
  '';

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

  # Host CLI: run Hermes as the container's Hermes user.
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
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./hermes/mcp
    ./hermes/profiles.nix
  ];

  # Container runtime.
  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Install the host CLI wrapper.
  environment.systemPackages = [
    hermesHostCli
  ];

  # Existing lockfile permission handling.
  systemd.tmpfiles.rules = [
    "z /var/lib/hermes/.hermes/installs/*/.install.lock 0660 hermes hermes -"
  ];

  # Prepare filesystem permissions and the Honcho provider
  # before starting the existing gateway container.
  systemd.services.hermes-agent.preStart = lib.mkAfter ''
    set -eu

    hermes_home="/var/lib/hermes/.hermes"

    # Host directory permissions.
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

    # --------------------------------------------------------
    # Declarative Honcho memory provider
    # --------------------------------------------------------

    plugin_root="$hermes_home/plugins"
    provider="$plugin_root/honcho"
    source="${honchoPlugin}"

    ${pkgs.coreutils}/bin/install \
      -d -o hermes -g hermes -m 2770 \
      "$plugin_root"

    # Remove only the old Nix-store symlink, if present.
    if [ -L "$provider" ]; then
      link_target="$(${pkgs.coreutils}/bin/readlink -- "$provider")"

      case "$link_target" in
        /nix/store/*-honcho-plugin)
          ${pkgs.coreutils}/bin/rm -- "$provider"
          ;;
        *)
          echo "Hermes: unexpected Honcho symlink: $link_target" >&2
          exit 1
          ;;
      esac
    fi

    # Never overwrite an unmanaged Honcho directory.
    if [ -e "$provider" ] && [ ! -f "$provider/.nix-managed-source" ]; then
      echo "Hermes: refusing to overwrite unmanaged Honcho directory" >&2
      exit 1
    fi

    # Install or update only when the pinned source changes.
    if [ ! -d "$provider" ] || \
       [ "$(${pkgs.coreutils}/bin/cat "$provider/.nix-managed-source" 2>/dev/null || true)" != "$source" ]; then

      echo "Hermes: deploying Honcho memory provider"

      staging="$(${pkgs.coreutils}/bin/mktemp -d \
        "$plugin_root/.honcho-stage.XXXXXX")"

      # Dereference Nix-store symlinks to create real files.
      ${pkgs.coreutils}/bin/cp -rL \
        "$source/." "$staging/"

      ${pkgs.coreutils}/bin/chmod -R u+rwX "$staging"

      printf '%s\n' "$source" > "$staging/.nix-managed-source"

      ${pkgs.coreutils}/bin/chown -R \
        hermes:hermes "$staging"

      ${pkgs.coreutils}/bin/chmod 0750 "$staging"

      # An existing directory can only be removed after
      # passing the managed-source check above.
      if [ -d "$provider" ]; then
        ${pkgs.coreutils}/bin/rm -rf -- "$provider"
      fi

      ${pkgs.coreutils}/bin/mv -- \
        "$staging" "$provider"
    fi
  '';

  # Hermes Agent configuration.
  services.hermes-agent = {
    enable = true;

    # Replaced by hermesHostCli.
    addToSystemPackages = false;

    container = {
      enable = true;
      backend = "podman";

      hostUsers = [
        "zanbee"
      ];

      image =
        "docker.io/library/ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54";
    };

    # SOPS-managed environment.
    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    # Honcho provider files are installed by preStart.
    # Do not also install them through extraPlugins:
    # that would create nix-managed-honcho-plugin.
    #
    # The pinned plugin source remains in the Nix closure
    # because it is referenced by preStart.

    extraPythonPackages = [
      honchoSdk
    ];

    # Self-hosted Honcho configuration.
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

    settings = {
      model = {
        provider = "openai-api";
        default = "gpt-5.4-mini";
        key_env = "OPENAI_API_KEY";
      };

      memory.provider = "honcho";

      plugins.enabled = [
        "honcho"
      ];
    };
  };
}
