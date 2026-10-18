{ config, pkgs, ... }:

{
  services.forgejo-runner = {
    package = pkgs.forgejo-runner;

    instances.default = {
      enable = true;

      runtimes.host = true;

      settings = {
        runner.labels = [
          "nixos:host"
        ];

        server.connections.forgejo = {
          url = "https://forgejo.fiordland-gar.ts.net";
          uuid = "4ae6fea5-7c66-4611-916a-a692592e7986";
        };
      };

      secrets.server.connections.forgejo.token_url =
        config.sops.secrets."sif/forgejo-runner-token".path;
    };
  };
}