{ ... }:
{
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";        # IPv4 /32 via routed DHCP
      IPv6AcceptRA = true; # IPv6 via RA/SLAAC
    };
    dhcpV4Config.UseDNS = true;
  };
}
