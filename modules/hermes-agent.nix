
# modules/hermes-agent.nix
{ inputs, config, pkgs, ... }:

let
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
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./mcp
  ];

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    container = {
      enable = true;
      backend = "podman";

      hostUsers = [ "zanbee" ];

      image =
        "docker.io/library/ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54";
    };

    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    # Official declarative plugin management
    extraPlugins = [
      honchoPlugin
    ];

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
