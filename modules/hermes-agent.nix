
# modules/hermes-agent.nix
{ inputs, config, ... }:

{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./mcp
  ];

  # Container backend
  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Hermes Agent
  services.hermes-agent = {
    enable = true;

    # Official NixOS CLI integration
    addToSystemPackages = true;

    container = {
      enable = true;
      backend = "podman";

      hostUsers = [ "zanbee" ];

      image =
        "docker.io/library/ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54";
    };

    # Secrets
    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    # Honcho configuration
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

    # Hermes settings
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
