cat hosts/sif/default.nix
{ config, modulesPath, pkgs, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/unifi.nix
    ../../modules/containers/beszel.nix
    ../../modules/containers/netalertx.nix
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

    # UniFi ports only
    allowedTCPPorts = [ 22 8443 8080 8843 8880 6789 ];
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

  # DNS caching
  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };

  apps.beszel-agent.enable = true;  

  # --------------------------------------------------
  # SOPS
  # --------------------------------------------------
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };

  # --------------------------------------------------
  # UniFi
  # --------------------------------------------------
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
  # Beszel
  # --------------------------------------------------
  apps.beszel = {
    enable = true;

    dataDir = "/var/lib/beszel";
    tailscaleStateDir = "/var/lib/tailscale-beszel";

    image = "docker.io/henrygd/beszel:latest";
    tailscaleImage = "docker.io/tailscale/tailscale:stable";

    tailscaleHostname = "beszel";
    tailscaleAuthFile = config.sops.secrets."sif/tailscale".path;
    tailscaleAdvertiseTags = [ "tag:container" ];

    # Use the public Tailscale URL you actually want Beszel to advertise
    appUrl = "https://beszel.fiordland-gar.ts.net";

    # Set to true if /dev/net/tun is problematic in Proxmox LXC
    userspaceNetworking = false;

    # Keep Beszel private to Tailscale
    openFirewall = false;

    # Declarative Tailscale Serve configuration
    serveConfigFile = ../../modules/containers/beszel-serve.json;
  };

  # --------------------------------------------------
  # System
  # --------------------------------------------------
  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];

    # --------------------------------------------------
  # NetAlertX
  # --------------------------------------------------
  apps.netalertx = {
    enable = true;

    dataDir = "/var/lib/netalertx";

    uid = 20211;
    gid = 20211;

    timezone = "Europe/Amsterdam";

    port = 20211;
    graphqlPort = 20212;

    # Keep this false if you only want to access it internally or over Tailscale
    openFirewall = false;
  };


}
[zanbee@michel-framework nixos]$ rm hosts/sif/default.nix
[zanbee@michel-framework nixos]$ vim hosts/sif/default.nix
[zanbee@michel-framework nixos]$ vim hosts/sif/default.nix
[zanbee@michel-framework nixos]$ cat hosts/sif/default.nix
{ config, modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/unifi.nix
    ../../modules/containers/beszel.nix
    ../../modules/containers/netalertx.nix
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

    # SSH + UniFi ports
    allowedTCPPorts = [ 22 8443 8080 8843 8880 6789 ];
    allowedUDPPorts = [ 3478 10001 1900 5514 ];
  };

  # Not useful in containers
  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;

  # --------------------------------------------------
  # TEMPORARY SSH BOOTSTRAP CONFIG
  # --------------------------------------------------
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
    PermitEmptyPasswords = lib.mkForce true;
  };

  # DNS caching
  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };

  # --------------------------------------------------
  # Beszel Agent (alleen als module bestaat!)
  # --------------------------------------------------
  apps.beszel-agent.enable = true;

  # --------------------------------------------------
  # SOPS
  # --------------------------------------------------
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };

  # --------------------------------------------------
  # UniFi
  # --------------------------------------------------
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

  systemd.services.podman-unifi.after = [ "network-online.target" "podman-unifi-db.service" ];
  systemd.services.podman-unifi.wants = [ "network-online.target" ];
  systemd.services.podman-unifi.requires = [ "podman-unifi-db.service" ];

  systemd.services.podman-unifi-db.after = [ "network-online.target" ];
  systemd.services.podman-unifi-db.wants = [ "network-online.target" ];

  # --------------------------------------------------
  # Beszel
  # --------------------------------------------------
  apps.beszel = {
    enable = true;

    dataDir = "/var/lib/beszel";
    tailscaleStateDir = "/var/lib/tailscale-beszel";

    image = "docker.io/henrygd/beszel:latest";
    tailscaleImage = "docker.io/tailscale/tailscale:stable";

    tailscaleHostname = "beszel";
    tailscaleAuthFile = config.sops.secrets."sif/tailscale".path;
    tailscaleAdvertiseTags = [ "tag:container" ];

    appUrl = "https://beszel.fiordland-gar.ts.net";

    userspaceNetworking = false;
    openFirewall = false;

    serveConfigFile = ../../modules/containers/beszel-serve.json;
  };

  # --------------------------------------------------
  # NetAlertX
  # --------------------------------------------------
  apps.netalertx = {
    enable = true;

    dataDir = "/var/lib/netalertx";

    uid = 20211;
    gid = 20211;

    timezone = "Europe/Amsterdam";

    port = 20211;
    graphqlPort = 20212;

    openFirewall = false;
  };

  # --------------------------------------------------
  # System
  # --------------------------------------------------
  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];
}
