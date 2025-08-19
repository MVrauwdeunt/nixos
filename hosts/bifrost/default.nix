{ lib, ... }:

let
  vhostsDir = ./vhosts;
  vhostFiles =
    map (f: vhostsDir + ("/" + f))
      (lib.attrNames (builtins.readDir vhostsDir));
in
{
  imports = [ 
    ./hardware-configuration.nix
    ../../modules/containers/podman-compose.nix
  ]
  ++ vhostFiles;

  # networking.hostName = "Bifrost";

  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  networking.useDHCP = lib.mkForce true;

  # Pas aan als je NVMe hebt:
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  # Activeer Caddy (Podman Compose); mailadres voor ACME
  modules.caddyCompose = {
    enable = true;
    email = "admin@gladsheimr.nl";
  };
}
