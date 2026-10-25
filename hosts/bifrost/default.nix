
{ lib, ... }:

let
  vhostsDir = ./vhosts;

  vhostNames =
    builtins.filter (f: lib.hasSuffix ".nix" f)
      (builtins.attrNames (builtins.readDir vhostsDir));

  vhostFiles =
    builtins.map (f: vhostsDir + ("/" + f)) vhostNames;

in
{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/containers/caddy.nix
      ../../modules/containers/authelia.nix
      ../../modules/users/zanbee
    ]
    ++ vhostFiles;

  # Keep traditional DHCP instead of systemd-networkd
  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  networking.useDHCP = lib.mkForce true;

  # GRUB
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  nix.settings.trusted-users = [
    "root"
    "zanbee"
  ];

  apps.beszel-agent.enable = true;

  # OCI containers (Podman backend)

  # Caddy v2.11.7 - linux/amd64
  # Pinned to the existing image digest on Bifrost
  apps.caddy = {
    enable = true;
    email = "admin@gladsheimr.nl";

    image = "docker.io/library/caddy:2.11.7@sha256:f2a1290d0463aad60660d4ec134943f183ee2a5f6c3eb7bf32dd984f2f020772";
  };

  # Authelia v4.39.28 - linux/amd64
  # Pinned to the existing image digest on Bifrost
  apps.authelia = {
    enable = true;

    image = "ghcr.io/authelia/authelia:4.39.28@sha256:bd97cff4fcbf715b5ff1f9ae286afbe6033afce385302520b0368122d43a6f54";

    # Modular OIDC clients
    oidc = {
      enable = true;

      openWebui.enable = true;
      actualBudget.enable = true;
      wallos.enable = true;
    };

    # SOPS secrets
    sops.file = ../../secrets.yaml;

    # Users database
    users = {
      zanbee = {
        displayName = "Zanbee";
        email = "authelia@openmailbox.nl";
        groups = [ "admins" ];
      };
    };

    # Optional cookie/portal tuning
    # cookie.domain = "gladsheimr.nl";
    # cookie.portalURL = "https://auth.gladsheimr.nl";
    # cookie.redirectURL = "https://auth.gladsheimr.nl";
  };

  # Service startup dependencies
  systemd.services.podman-caddy.after = [
    "network-online.target"
    "tailscaled.service"
  ];

  systemd.services.podman-caddy.wants = [
    "network-online.target"
  ];

  systemd.services.podman-authelia.after = [
    "network-online.target"
    "tailscaled.service"
  ];

  systemd.services.podman-authelia.wants = [
    "network-online.target"
  ];

  # Allow UDP for live streams
  networking.firewall.allowedUDPPorts = [ 8189 ];
}
