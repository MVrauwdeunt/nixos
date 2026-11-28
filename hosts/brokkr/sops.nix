
{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    validateSopsFiles = true;

    age = {
      sshKeyPaths = [];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
    };

    gnupg.sshKeyPaths = [];

    secrets = {
      tailscaleAuthKey = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      forgejoRunnerToken = {
        owner = "root";
        group = "root";
        mode = "0400";

        restartUnits = [ "forgejo-runner.service" ];
      };
    };
  };
}
