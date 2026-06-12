{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = false;

    environmentFiles = [
      config.sops.secrets."vili/hermes/env".path
    ];

    settings = {
      model = {
        provider = "openai";
        default = "gpt-5.1";
      };
    };

    addToSystemPackages = true;
  };
}