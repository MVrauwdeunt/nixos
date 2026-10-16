
# modules/hermes-agent.nix
{ inputs, config, pkgs, lib, ... }:

let
  # Officiële Honcho-plugin uit de flake-input.
  honchoPlugin = pkgs.runCommand "hermes-honcho-plugin" {} ''
    mkdir -p "$out"
    cp -r ${inputs.honcho}/hermes-plugin-honcho/. "$out/"
  '';

  # Gebruik dezelfde Python-package-set als Hermes.
  python = config.services.hermes-agent.package.python.pkgs;

  # Honcho SDK zonder dubbele dependencies.
  # httpx en pydantic zitten al in Hermes' sealed venv.
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
  ];

  # --------------------------------------------------
  # Container backend
  # --------------------------------------------------

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # --------------------------------------------------
  # Hermes CLI-wrapper
  # --------------------------------------------------

  environment.systemPackages = [
    pkgs.podman

    (pkgs.writeShellScriptBin "hermes" ''
      exec sudo ${pkgs.podman}/bin/podman exec -it hermes-agent \
        env HERMES_HOME=/data/.hermes HOME=/home/hermes \
        /data/current-package/bin/hermes "$@"
    '')
  ];

  # --------------------------------------------------
  # Honcho plugin alias
  # --------------------------------------------------

  # Hermes zoekt de memory-plugin onder plugins/honcho.
  # De NixOS-module maakt zelf een nix-managed symlink.
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

    container = {
      enable = true;
      backend = "podman";
    };

    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    # Honcho-plugin en bijbehorende Python SDK.
    extraPlugins = [
      honchoPlugin
    ];

    extraPythonPackages = [
      honchoSdk
    ];

    # ------------------------------------------------
    # Honcho clientconfiguratie
    # ------------------------------------------------

    # Honcho API draait op Vili in een aparte container.
    # Hermes gebruikt host networking en bereikt
    # Honcho via 127.0.0.1:8000.
    hermesHomeFiles."honcho.json" = builtins.toJSON {
      baseUrl = "http://127.0.0.1:8000";

      hosts.hermes = {
        enabled = true;

        workspace = "hermes";
        aiPeer = "hermes";
        peerName = "michel";

        # Voorkomt een lege session key vanuit de CLI.
        sessionStrategy = "global";

        # Eén gebruikersidentiteit voor de kanalen.
        pinUserPeer = true;

        recallMode = "hybrid";
        writeFrequency = "async";
      };
    };

    # ------------------------------------------------
    # Hermes instellingen
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
