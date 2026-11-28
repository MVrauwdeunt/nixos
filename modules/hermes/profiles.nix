
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
# SYNTH  -> Forgejo (read/write, pull requests)
# PULSE  -> Allos

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
      provider = "openai-codex";
      default = "gpt-6.2-sol";
      api_mode = "codex_responses";
      key_env = "";
      base_url = "";
    };
  };

  # PULSE - Allos MCP
  allosMcp =
    (import ./mcp/servers/allos.nix { })
      .services.hermes-agent.mcpServers.allos;

  pulseConfig = builtins.toJSON (
    agentConfig // {
      mcp_servers.allos = allosMcp;
    }
  );

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
  # SYNTH - Forgejo MCP runtime launcher
  # ------------------------------------------------------------

  # Load the SOPS-managed Forgejo token at runtime.
  # Configure the Forgejo URL through its environment variable.
  # Never embed the token in the Nix store.

  forgejoSynthLauncher = pkgs.writeShellScript "forgejo-synth-mcp" ''
    set -eu

    env_file="/data/.hermes/profiles/synth/.env"

    if [ ! -r "$env_file" ]; then
      echo "Forgejo MCP: SYNTH environment file unavailable" >&2
      exit 1
    fi

    FORGEJO_ACCESS_TOKEN="$(
      ${pkgs.gnused}/bin/sed -n \
        's/^FORGEJO_SYNTH_TOKEN=//p' \
        "$env_file"
    )"

    if [ -z "$FORGEJO_ACCESS_TOKEN" ]; then
      echo "Forgejo MCP: SYNTH token missing" >&2
      exit 1
    fi

    export FORGEJO_ACCESS_TOKEN
    export FORGEJO_URL="https://forgejo.fiordland-gar.ts.net"

    exec ${pkgs.forgejo-mcp}/bin/forgejo-mcp "$@"
  '';

  # ------------------------------------------------------------
  # SYNTH - Forgejo MCP
  # ------------------------------------------------------------

  # Forgejo access is controlled by:
  # 1. The SYNTH account's collaborator permissions.
  # 2. The access token's repository permissions.
  # 3. Forgejo branch protection rules.
  #
  # Merge and delete tools are deliberately excluded.

  forgejoSynthMcp = {
    enabled = true;

    command = "${forgejoSynthLauncher}";

    args = [
      "--transport"
      "stdio"
    ];

    timeout = 120;
    connect_timeout = 30;

    tools = {
      include = [
        # Repository discovery
        "search_repos"
        "list_branches"
        "get_repo_tree"
        "list_repo_contents"
        "get_file_content"
        "list_repo_commits"

        # Pull request inspection
        "list_repo_pull_requests"
        "get_pull_request_diff"

        # Branch management
        "create_branch"

        # Code modifications
        "change_files"
        "create_file"
        "update_file"

        # Pull request creation
        "create_pull_request"
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

  sops.secrets."saga/allos_mcp_token" = {
    sopsFile = ../../secrets.yaml;
  };

  sops.secrets."saga/actual_mcp_bearer_token" = {
    sopsFile = ../../secrets.yaml;
  };

  sops.secrets."sif/homelable_mcp_api_key" = {
    sopsFile = ../../secrets.yaml;
  };

  # Dedicated Forgejo token for SYNTH.
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
    "profiles/pulse/config.yaml" = pulseConfig;
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
        # SYNTH receives the Forgejo token.
        # PULSE receives the Allos MCP token.
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

          if [ "$profile" = "pulse" ]; then
            printf 'ALLOS_MCP_TOKEN=%s\n' \
              "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."saga/allos_mcp_token".path})"
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
