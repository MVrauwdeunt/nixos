{ self, deploy-rs, system }:
{
  nodes = {
    sif = {
      hostname = "sif.fiordland-gar.ts.net";
      sshUser = "zanbee";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.sif;
      };
    };

    bifrost = {
      hostname = "bifrost.fiordland-gar.ts.net";
      sshUser = "zanbee";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.bifrost;
      };
    };
    mimir = {
      hostname = "mimir.fiordland-gar.ts.net";
      sshUser = "zanbee";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.sif;
      };
    };
  };
}
