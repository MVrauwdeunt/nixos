{ lib, ... }:
{
  # voorspelbare namen uit → gebruik 'eth0'
  networking.usePredictableInterfaceNames = lib.mkForce false;

  # gebruik networkd + DHCP
  networking.useNetworkd = true;
  networking.useDHCP = true;

  # systemd-networkd: vang eth0 op
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";        # Hetzner geeft IPv4 /32 + route via DHCP
      IPv6AcceptRA = true; # IPv6 via RA
    };
    dhcpV4Config.UseDNS = true;
  };

  # verwijder evt. MAC→eth0 udev rename die te laat/anders triggert
  services.udev.extraRules = lib.mkForce "";

  # (optioneel) iets langere rootdelay
  boot.kernelParams = [ "rootdelay=20" ];
}

