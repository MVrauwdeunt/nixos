
# modules/hermes/profiles.nix
#
# Declarative Asgard AI agent profiles.
#
# NYX uses the default Hermes profile.
# Specialized profiles:
#   WRAITH, VESPER, LYRA, SYNTH, PULSE
#
# Secrets come from SOPS, never from the Nix store.

{ config, pkgs, ... }:

let
  profiles = [
    "wraith"
    "vesper"
    "lyra"
    "synth"
    "pulse"
  ];

  # Runtime directories required by Hermes.
  runtimeDirs = [
    "cron"
    "sessions"
    "logs"
    "logs/curator"
    "memories"
    "pairing"
    "hooks"
    "image_cache"
    "audio_cache"
    "skills"
  ];

  # Shared directory permissions:
  # owner: rwx
  # group: rwx
  # others: none
  # setgid: inherit group ownership
  directoryMode = "2770";

  agentModel = builtins.toJSON {
    model = {
      provider = "openai-api";
      default = "gpt-5.4-mini";
      key_env = "OPENAI_API_KEY";
    };
  };

in
{
  # ------------------------------------------------------------
  # Declarative agent identities
  # ------------------------------------------------------------

  services.hermes-agent.hermesHomeFiles = {
    # NYX - Central coordinator
    "SOUL.md" = ./agents/nyx/SOUL.md;

    # WRAITH - Infrastructure and security
    "profiles/wraith/SOUL.md" =
      ./agents/wraith/SOUL.md;

    # VESPER - Finance
    "profiles/vesper/SOUL.md" =
      ./agents/vesper/SOUL.md;

    # LYRA - Home Assistant and automation
    "profiles/lyra/SOUL.md" =
      ./agents/lyra/SOUL.md;

    # SYNTH - Software engineering
    "profiles/synth/SOUL.md" =
      ./agents/synth/SOUL.md;

    # PULSE - Health and performance
    "profiles/pulse/SOUL.md" =
      ./agents/pulse/SOUL.md;

    # Profile model configurations
    "profiles/wraith/config.yaml" = agentModel;
    "profiles/vesper/config.yaml" = agentModel;
    "profiles/lyra/config.yaml" = agentModel;
    "profiles/synth/config.yaml" = agentModel;
    "profiles/pulse/config.yaml" = agentModel;
  };

  # ------------------------------------------------------------
  # Profile directory and credential provisioning
  # ------------------------------------------------------------

  system.activationScripts.hermesAgentProfileKeys = {
    deps = [
      "users"
      "setupSecrets"
    ];

    text = ''
      set -eu

      source_env=${config.sops.secrets."vili/hermes/env".path}

      # Read provider credentials from SOPS.
      # Never print the API key.
      openai_line="$(
        ${pkgs.gawk}/bin/awk -F= \
          '$1 == "OPENAI_API_KEY" { print; exit }' \
          "$source_env"
      )"

      if [ -z "$openai_line" ]; then
        echo "Hermes: OPENAI_API_KEY missing" >&2
        exit 1
      fi

      # Provision shared profile root.
      ${pkgs.coreutils}/bin/install \
        -d \
        -o hermes \
        -g hermes \
        -m ${directoryMode} \
        /var/lib/hermes/.hermes/profiles

      for profile in ${builtins.concatStringsSep " " profiles}; do

        profile_dir="/var/lib/hermes/.hermes/profiles/$profile"

        # Both the container user and authorized host users
        # need access to the selected profile.
        ${pkgs.coreutils}/bin/install \
          -d \
          -o hermes \
          -g hermes \
          -m ${directoryMode} \
          "$profile_dir"

        # Provision all required runtime directories.
        # Existing directories and their contents are preserved.
        for subdir in ${builtins.concatStringsSep " " runtimeDirs}; do

          ${pkgs.coreutils}/bin/install \
            -d \
            -o hermes \
            -g hermes \
            -m ${directoryMode} \
            "$profile_dir/$subdir"

        done

        # Install profile-specific provider credentials.
        #
        # 0640:
        # hermes user  = read/write
        # hermes group = read
        # others       = no access
        printf '%s\n' "$openai_line" | \
          ${pkgs.coreutils}/bin/install \
            -o hermes \
            -g hermes \
            -m 0640 \
            /dev/stdin \
            "$profile_dir/.env"

      done

      unset openai_line
    '';
  };
}
