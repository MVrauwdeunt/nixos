
# modules/hermes/profiles.nix
#
# Declarative Asgard AI agent profiles.
# NYX uses the default profile.
#
# Specialized agents:
# WRAITH, VESPER, LYRA, SYNTH, PULSE
#
# MCP assignments:
# WRAITH -> Homelable
# VESPER -> Actual Budget
# LYRA   -> Home Assistant
# SYNTH  -> Forgejo (read-only)
# PULSE  -> No MCP server

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

  # ------------------------------------------------------------
  # Shared model configuration
  # ------------------------------------------------------------

  agentConfig = {
    model = {
      provider = "openai-api";
      default = "gpt-5.4-mini";
      key_env = "OPENAI_API_KEY";
    };
  };

  agentModel = builtins.toJSON agentConfig;

  # ------------------------------------------------------------
  # LYRA - Home Assistant MCP
  # ------------------------------------------------------------

  homeAssistantMcp =
    (import ./mcp/servers/homeassistant.nix { })
      .services.hermes-agent.mcpServers.homeassistant;

  lyraConfig = builtins.toJSON (
    agentConfig // {
      mcp_servers.homeassistant = homeAssistantMcp;
    }
  );

  # ------------------------------------------------------------
  # VESPER - Actual Budget MCP
  # ------------------------------------------------------------

  actualBudgetMcp = {
    enabled = true;

    url = "http://saga.fiordland-gar.ts.net:3101/mcp";

    headers.Authorization =
      "Bearer \${ACTUAL_MCP_TOKEN}";

    timeout = 120;
    connect_timeout = 30;
  };

  vesperConfig = builtins.toJSON (
    agentConfig // {
      mcp_servers.actual_budget = actualBudgetMcp;
    }
  );

  # ------------------------------------------------------------
  # WRAITH - Homelable MCP
  # ------------------------------------------------------------

  homelableMcp =
    (import ./mcp/servers/homelable.nix { })
      .services.hermes-agent.mcpServers.homelable;

  wraithConfig = builtins.toJSON (
    agentConfig // {
      mcp_servers.homelable = homelableMcp;
    }
  );

  # ------------------------------------------------------------
  # SYNTH - Forgejo MCP (read-only)
  # ------------------------------------------------------------

  # Run the MCP server locally through stdio.
  # No additional HTTP server or exposed port is required.
  #
  # The personal access token is loaded from SYNTH's .env.
  # Only read-only MCP tools are registered.
  #
  # Read-only permissions must also be enforced
  # by the Forgejo access token.

  forgejoSynthMcp = {
    enabled = true;

    command = "${pkgs.forgejo-mcp}/bin/forgejo-mcp";

    args = [
      "--transport"
      "stdio"
      "--url"
      "https://forgejo.fiordland-gar.ts.net"
    ];

    env.FORGEJO_ACCESS_TOKEN =
      "\${FORGEJO_SYNTH_TOKEN}";

    timeout = 120;
    connect_timeout = 30;

    tools = {
      include = [
        "search_repos"
        "list_branches"
        "get_repo_tree"
        "list_repo_contents"
        "get_file_content"
        "list_repo_commits"
        "list_repo_pull_requests"
        "get_pull_request_diff"
      ];

      resources = false;
      prompts = false;
    };
  };

  synthConfig = builtins.toJSON (
    agentConfig // {
      mcp_servers.forgejo = forgejoSynthMcp;
    }
  );

in
{
  # ------------------------------------------------------------
  # SOPS secrets
  # ------------------------------------------------------------

  sops.secrets."saga/actual_mcp_bearer_token" = {
    sopsFile = ../../secrets.yaml;
  };

  sops.secrets."sif/homelable_mcp_api_key" = {
    sopsFile = ../../secrets.yaml;
  };

  # Dedicated read-only Forgejo token for SYNTH.
  sops.secrets."vili/hermes/forgejo-synth-token" = {
    sopsFile = ../../secrets.yaml;
  };

  # ------------------------------------------------------------
  # Declarative Hermes profile files
  # ------------------------------------------------------------

  services.hermes-agent.hermesHomeFiles = {

    # NYX - Central coordinator
    "SOUL.md" = ./agents/nyx/SOUL.md;

    # Agent identities
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

    # Agent configurations
    "profiles/wraith/config.yaml" = wraithConfig;
    "profiles/vesper/config.yaml" = vesperConfig;
    "profiles/lyra/config.yaml" = lyraConfig;
    "profiles/synth/config.yaml" = synthConfig;
    "profiles/pulse/config.yaml" = agentModel;
  };

  # ------------------------------------------------------------
  # Runtime directories and SOPS credentials
  # ------------------------------------------------------------

  system.activationScripts.hermesAgentProfileKeys = {
    deps = [
      "users"
      "setupSecrets"
    ];

    text = ''
      set -eu

      # --------------------------------------------------------
      # Credential sources
      # --------------------------------------------------------

      source_env=${config.sops.secrets."vili/hermes/env".path}

      actual_token_file=${config.sops.secrets."saga/actual_mcp_bearer_token".path}

      homelable_token_file=${config.sops.secrets."sif/homelable_mcp_api_key".path}

      forgejo_synth_token_file=${config.sops.secrets."vili/hermes/forgejo-synth-token".path}

      # --------------------------------------------------------
      # OpenAI credential
      # --------------------------------------------------------

      openai_line="$(
        ${pkgs.gawk}/bin/awk -F= \
          '$1 == "OPENAI_API_KEY" { print; exit }' \
          "$source_env"
      )"

      if [ -z "$openai_line" ]; then
        echo "Hermes: OPENAI_API_KEY missing" >&2
        exit 1
      fi

      # --------------------------------------------------------
      # Actual Budget credential
      # --------------------------------------------------------

      actual_mcp_token="$(
        ${pkgs.coreutils}/bin/cat "$actual_token_file"
      )"

      if [ -z "$actual_mcp_token" ]; then
        echo "Hermes: Actual MCP bearer token missing" >&2
        exit 1
      fi

      # --------------------------------------------------------
      # Homelable credential
      # --------------------------------------------------------

      homelable_mcp_key="$(
        ${pkgs.coreutils}/bin/cat "$homelable_token_file"
      )"

      if [ -z "$homelable_mcp_key" ]; then
        echo "Hermes: Homelable MCP API key missing" >&2
        exit 1
      fi

      # --------------------------------------------------------
      # Forgejo SYNTH credential
      # --------------------------------------------------------

      forgejo_synth_token="$(
        ${pkgs.coreutils}/bin/cat "$forgejo_synth_token_file"
      )"

      if [ -z "$forgejo_synth_token" ]; then
        echo "Hermes: Forgejo SYNTH token missing" >&2
        exit 1
      fi

      # --------------------------------------------------------
      # Profile root directory
      # --------------------------------------------------------

      ${pkgs.coreutils}/bin/install \
        -d \
        -o hermes \
        -g hermes \
        -m ${directoryMode} \
        /var/lib/hermes/.hermes/profiles

      # --------------------------------------------------------
      # Provision specialized profiles
      # --------------------------------------------------------

      for profile in ${builtins.concatStringsSep " " profiles}; do

        profile_dir="/var/lib/hermes/.hermes/profiles/$profile"

        # Create profile directory.
        ${pkgs.coreutils}/bin/install \
          -d \
          -o hermes \
          -g hermes \
          -m ${directoryMode} \
          "$profile_dir"

        # Create runtime directories.
        for subdir in ${builtins.concatStringsSep " " runtimeDirs}; do

          ${pkgs.coreutils}/bin/install \
            -d \
            -o hermes \
            -g hermes \
            -m ${directoryMode} \
            "$profile_dir/$subdir"

        done

        # ------------------------------------------------------
        # Profile-specific credentials
        # ------------------------------------------------------

        # All profiles receive the OpenAI credential.
        # WRAITH receives Homelable credentials.
        # VESPER receives Actual Budget credentials.
        # SYNTH receives the read-only Forgejo token.
        # PULSE receives no additional MCP credentials.
        #
        # File mode: 0640
        # Owner/group: hermes/hermes

        {
          printf '%s\n' "$openai_line"

          if [ "$profile" = "wraith" ]; then
            printf 'HOMELABLE_MCP_API_KEY=%s\n' \
              "$homelable_mcp_key"
          fi

          if [ "$profile" = "vesper" ]; then
            printf 'ACTUAL_MCP_TOKEN=%s\n' \
              "$actual_mcp_token"
          fi

          if [ "$profile" = "synth" ]; then
            printf 'FORGEJO_SYNTH_TOKEN=%s\n' \
              "$forgejo_synth_token"
          fi

        } | ${pkgs.coreutils}/bin/install \
          -o hermes \
          -g hermes \
          -m 0640 \
          /dev/stdin \
          "$profile_dir/.env"

      done

      # --------------------------------------------------------
      # Clear local credential variables
      # --------------------------------------------------------

      unset openai_line
      unset actual_mcp_token
      unset homelable_mcp_key
      unset forgejo_synth_token
    '';
  };
}
