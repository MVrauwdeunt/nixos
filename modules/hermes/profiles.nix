
# modules/hermes/profiles.nix
#
# Declarative Asgard AI agent profiles.
# NYX uses the default profile.
#
# Specialized agents:
# WRAITH, VESPER, LYRA, SYNTH, PULSE

{ config, pkgs, ... }:

let
  profiles = [
    "wraith"
    "vesper"
    "lyra"
    "synth"
    "pulse"
  ];

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
    "mcp-tokens"
  ];

  directoryMode = "2770";

  # Shared model configuration.
  agentConfig = {
    model = {
      provider = "openai-api";
      default = "gpt-5.4-mini";
      key_env = "OPENAI_API_KEY";
    };
  };

  agentModel = builtins.toJSON agentConfig;

  # Reuse the existing Home Assistant MCP definition.
  # No duplicate URL or OAuth configuration.
  homeAssistantMcp =
    (import ./mcp/servers/homeassistant.nix { })
      .services.hermes-agent.mcpServers.homeassistant;

  # LYRA's individual model and MCP configuration.
  lyraConfig = builtins.toJSON (
    agentConfig // {
      mcp_servers.homeassistant = homeAssistantMcp;
    }
  );

in
{
  services.hermes-agent.hermesHomeFiles = {

    # NYX: central coordinator.
    "SOUL.md" = ./agents/nyx/SOUL.md;

    # Agent identities.
    "profiles/wraith/SOUL.md" =
      ./agents/wraith/SOUL.md;

    "profiles/vesper/SOUL.md" =
      ./agents/vesper/SOUL.md;

    "profiles/lyra/SOUL.md" =
      ./agents/lyra/SOUL.md;

    "profiles/synth/SOUL.md" =
      ./agents/synth/SOUL.md;

    "profiles/pulse/SOUL.md" =
      ./agents/pulse/SOUL.md;

    # Profile configurations.
    "profiles/wraith/config.yaml" = agentModel;
    "profiles/vesper/config.yaml" = agentModel;

    # LYRA gets Home Assistant MCP.
    "profiles/lyra/config.yaml" = lyraConfig;

    "profiles/synth/config.yaml" = agentModel;
    "profiles/pulse/config.yaml" = agentModel;
  };

  # Runtime directories and SOPS credentials.
  system.activationScripts.hermesAgentProfileKeys = {
    deps = [
      "users"
      "setupSecrets"
    ];

    text = ''
      set -eu

      source_env=${config.sops.secrets."vili/hermes/env".path}

      openai_line="$(
        ${pkgs.gawk}/bin/awk -F= \
          '$1 == "OPENAI_API_KEY" { print; exit }' \
          "$source_env"
      )"

      if [ -z "$openai_line" ]; then
        echo "Hermes: OPENAI_API_KEY missing" >&2
        exit 1
      fi

      # Provision profile root.
      ${pkgs.coreutils}/bin/install \
        -d \
        -o hermes \
        -g hermes \
        -m ${directoryMode} \
        /var/lib/hermes/.hermes/profiles

      for profile in ${builtins.concatStringsSep " " profiles}; do

        profile_dir="/var/lib/hermes/.hermes/profiles/$profile"

        # Shared profile directory.
        ${pkgs.coreutils}/bin/install \
          -d \
          -o hermes \
          -g hermes \
          -m ${directoryMode} \
          "$profile_dir"

        # Hermes runtime directories.
        for subdir in ${builtins.concatStringsSep " " runtimeDirs}; do

          ${pkgs.coreutils}/bin/install \
            -d \
            -o hermes \
            -g hermes \
            -m ${directoryMode} \
            "$profile_dir/$subdir"

        done

        # Install provider credentials from SOPS.
        # Owner: read/write
        # Group: read
        # Others: no access

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
