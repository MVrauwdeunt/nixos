{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  environment.systemPackages = [
    pkgs.podman

    (pkgs.writeShellScriptBin "hermes" ''
      exec sudo ${pkgs.podman}/bin/podman exec -it hermes-agent \
        env HERMES_HOME=/data/.hermes HOME=/home/hermes \
        /data/current-package/bin/hermes "$@"
    '')
  ];

  services.hermes-agent = {
    enable = true;

    container = {
      enable = true;
      backend = "podman";
    };

    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    settings = {
      model = {
        provider = "openai-api";
        default = "gpt-5.5";
      };
    };
  };
}