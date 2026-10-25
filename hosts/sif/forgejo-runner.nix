
{ config, pkgs, ... }:

{
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;

    instances.default = {
      enable = true;

      name = "sif-nixos";

      url = "https://forgejo.fiordland-gar.ts.net";

      tokenFile =
        config.sops.secrets."sif/forgejo-runner-token".path;

      labels = [
        "nixos:host"
      ];

      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        git
        jq
        nix
        nodejs
        gnutar
        gzip
      ];
    };
  };
}
