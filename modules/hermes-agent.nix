
# modules/hermes-agent.nix
{ inputs, config, pkgs, lib, ... }:

let
  # Official Honcho plugin from flake input.
  honchoPlugin = pkgs.runCommand "hermes-honcho-plugin" {} ''
    mkdir -p "$out"
    cp -r ${inputs.honcho}/hermes-plugin-honcho/. "$out/"
  '';

  # Use the same Python package set as Hermes.
  python = config.services.hermes-agent.package.python.pkgs;

  # Honcho SDK without duplicate dependencies.
  honchoSdk = python.buildPythonPackage {
    pname = "honcho-ai";

    version =
      (builtins.fromTOML
        (builtins.readFile
          "${inputs.honcho}/sdks/python/pyproject.toml"
        )
      ).project.version;

    src = "${inputs.honcho}/sdks/python";

    pyproject = true;

    build-system = with python; [
      setuptools
      wheel
    ];

    dependencies = [ ];

    pythonRemoveDeps = [
      "httpx"
      "pydantic"
    ];

    doCheck = false;
  };

in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./mcp
  ];

  # --------------------------------------------------
  # Container backend
  # --------------------------------------------------

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # --------------------------------------------------
  # Honcho plugin alias
  # --------------------------------------------------

  system.activationScripts.hermes-honcho-alias =
    lib.stringAfter [ "hermes-agent-setup" ] ''
      ln -sfn ${honchoPlugin} /var/lib/hermes/.hermes/plugins/honcho
      chown -h hermes:hermes /var/lib/hermes/.hermes/plugins/honcho
    '';

  # --------------------------------------------------
  # Hermes Agent
  # --------------------------------------------------

  services.hermes-agent = {
    enable = true;

    # Use the official NixOS CLI integration.
    # No custom Podman exec wrapper.
    addToSystemPackages = true;

    container = {
      enable = true;
      backend = "podman";

      # Allow zanbee to use the managed Hermes CLI.
      hostUsers = [ "zanbee" ];

      # Ubuntu 24.04, pinned image.
      image =
        "docker.io/library/ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54";
    };

    # ------------------------------------------------
    # Secrets
    # ------------------------------------------------

    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    # ------------------------------------------------
    # Plugins
    # ------------------------------------------------

    extraPlugins = [
      honchoPlugin
    ];

    extraPythonPackages = [
      honchoSdk
    ];

    # ------------------------------------------------
    # Honcho configuration
    # ------------------------------------------------

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

    # ------------------------------------------------
    # Hermes settings
    # ------------------------------------------------

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
