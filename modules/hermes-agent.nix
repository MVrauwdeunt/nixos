
{ inputs, config, pkgs, ... }:

let
  pythonPackages =
    config.services.hermes-agent.package.python.pkgs;

  # Honcho plugin en SDK uit dezelfde gepinde revisie.
  honchoSource = pkgs.fetchFromGitHub {
    owner = "plastic-labs";
    repo = "honcho";
    rev = "7dd3702933d5cc1ce1f0a44bba6525cc61ee6e16";
    hash = "sha256-NmThEGtoEX9HDWjAB6czuRSyf95lCeu/dkTONUM9thU=";
  };

  # Declaratieve Hermes-plugin.
  honchoPlugin = pkgs.runCommand "honcho-plugin" { } ''
    mkdir -p "$out"
    cp -r ${honchoSource}/hermes-plugin-honcho/. "$out/"
  '';

  # Honcho SDK 2.8.0.
  # Bestaande Python-dependencies worden door Hermes geleverd.
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

in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./mcp
  ];

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Hermes zoekt specifiek naar plugins/honcho.
  # De officiële module maakt daarnaast zijn eigen
  # nix-managed-honcho-plugin symlink.
  #
  # L+ vervangt een bestaande symlink wanneer nodig.
  #
  # z herstelt de groepsrechten van bestaande lockfiles
  # tijdens tmpfiles-verwerking.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/hermes/.hermes/plugins/honcho - - - - ${honchoPlugin}"
    "z /var/lib/hermes/.hermes/installs/*/.install.lock 0660 hermes hermes -"
  ];

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

    # Officiële declaratieve pluginregistratie.
    extraPlugins = [
      honchoPlugin
    ];

    # SDK beschikbaar maken via Hermes' Python-wrapper.
    extraPythonPackages = [
      honchoSdk
    ];

    # Self-hosted Honcho.
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
