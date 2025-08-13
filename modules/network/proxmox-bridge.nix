{ ... }:
{
  networking.useNetworkd = true;
  networking.useDHCP = true;

  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en*";
    networkConfig = { DHCP = "yes"; IPv6AcceptRA = true; };
  };
}
