{ config, modulesPath, pkgs, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/unifi.nix
  ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = false;
    privileged = true;
  };

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

    # Keep existing ports + nginx (80/443)
    allowedTCPPorts = [ 22 80 443 8443 8080 8843 8880 6789 ];
    allowedUDPPorts = [ 3478 10001 1900 5514 ];
  };

  # Not useful in containers
  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;

  # --------------------------------------------------
  # TEMPORARY SSH BOOTSTRAP CONFIG
  # Remove this after SSH key login works
  # --------------------------------------------------
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
    PermitEmptyPasswords = lib.mkForce true;
  };

  # DNS caching (optional)
  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };

  # --------------------------------------------------
  # Beszel (native, no containers)
  # --------------------------------------------------
  services.beszel.hub = {
    enable = true;

    # Local port (only used internally via nginx)
    port = 8090;
  };

  # nginx reverse proxy for Beszel
  services.nginx = {
    enable = true;

    virtualHosts."beszel.jouwdomein.nl" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.beszel.hub.port}";
        proxyWebsockets = true;
      };
    };
  };

  # ACME (Let's Encrypt)
  security.acme = {
    acceptTerms = true;
    defaults.email = "jij@jouwdomein.nl";
  };

  # UniFi
  apps.unifi = {
    enable = true;

    dataDir = "/var/lib/unifi";

    uid = 1000;
    gid = 1000;

    timezone = "Europe/Amsterdam";

    image = "lscr.io/linuxserver/unifi-network-application:10.1.89";
    mongoImage = "docker.io/mongo:8.0";

    mongoUser = "unifi";
    mongoPassword = "vervang-dit-met-een-goed-wachtwoord";
  };

  # Make sure generated Podman units wait for networking
  systemd.services.podman-unifi.after = [ "network-online.target" "podman-unifi-db.service" ];
  systemd.services.podman-unifi.wants = [ "network-online.target" ];
  systemd.services.podman-unifi.requires = [ "podman-unifi-db.service" ];

  systemd.services.podman-unifi-db.after = [ "network-online.target" ];
  systemd.services.podman-unifi-db.wants = [ "network-online.target" ];

  # --------------------------------------------------
  # TEMPORARY: disable secrets during bootstrap
  # --------------------------------------------------

  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];
}
