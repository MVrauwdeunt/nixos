# hosts/bifrost/default.nix
{ lib, ... }:

let
  vhostsDir = ./vhosts;
  vhostNames =
    builtins.filter (f: lib.hasSuffix ".nix" f)
      (builtins.attrNames (builtins.readDir vhostsDir));
  vhostFiles = builtins.map (f: vhostsDir + ("/" + f)) vhostNames;
in
{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/containers/caddy.nix
      ../../modules/containers/authelia.nix
    ]
    ++ vhostFiles;

  # networking.hostName = "bifrost";

  # Keep traditional DHCP instead of systemd-networkd on this host
  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  networking.useDHCP = lib.mkForce true;

  # GRUB boot on /dev/sda (adjust if NVMe)
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # --- OCI containers (Podman backend) ---
  apps.caddy = {
    enable = true;
    email  = "admin@gladsheimr.nl";
    # vhosts are collected from ./vhosts/*.nix
  };

  # Authelia with field-level secrets via sops
  apps.authelia = {
    enable = true;

    # Point to your sops file; only short secrets are needed:
    #   authelia/jwt_secret
    #   authelia/session_secret
    #   authelia/storage_encryption_key
    #   authelia/users/zanbee_password  (argon2id hash)
    sops.file = ../../secrets.yaml;

    # Declare at least one user. The password hash is read from the sops key
    # "authelia/users/zanbee_password" by default (can be overridden per user).
    users = {
      zanbee = {
        displayName = "Zanbee";
        email       = "authelia@openmailbox.nl";
        groups      = [ "admins" ];
        # passwordKey = "authelia/users/zanbee_password"; # optional (default matches this)
      };
    };

    # Optional cookie/portal tuning (defaults already match these values)
    # cookie.domain      = "gladsheimr.nl";
    # cookie.portalURL   = "https://auth.gladsheimr.nl";
    # cookie.redirectURL = "https://auth.gladsheimr.nl";
  };

  # Order nicely after network/tailscale so upstreams are reachable on boot
  systemd.services.podman-caddy.after = [ "network-online.target" "tailscaled.service" ];
  systemd.services.podman-caddy.wants = [ "network-online.target" ];
  systemd.services.podman-authelia.after = [ "network-online.target" "tailscaled.service" ];
  systemd.services.podman-authelia.wants = [ "network-online.target" ];
}
