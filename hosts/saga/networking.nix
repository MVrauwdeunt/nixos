{ lib, ... }:
{
  # Network config for Proxmox LXC (eth0 via DHCP)
  networking.useDHCP = lib.mkForce false;
  networking.useNetworkd = lib.mkForce true;

  systemd.network.enable = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;

    # SSH + UniFi ports
    allowedTCPPorts = [ 22 ];
  };
}
