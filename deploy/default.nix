{ self, deploy-rs, system }:
{
  nodes = {
    sif = {
      hostname = "192.168.100.150";
      sshUser = "zanbee";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.sif;
        magicRollback = false;
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
      hostname = "192.168.178.240";
      sshUser = "zanbee";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.mimir;
      };
    };
  };
}
