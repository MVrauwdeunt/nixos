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
    config.services.hermes-agent.package

    (pkgs.writeShellScriptBin "hermes-container" ''
      exec ${pkgs.podman}/bin/podman exec -it hermes-agent \
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
        provider = "openai";
        default = "gpt-5.1";
      };
    };
  };
}