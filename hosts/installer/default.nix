{ config, pkgs, lib, sops-nix, nixpkgs, ... }:

{
  # Minimal NixOS installer ISO base
  imports = [
    # Flake-friendly import of the installer module
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

    # sops-nix module (must be provided via flake inputs)
    sops-nix.nixosModules.sops
  ];

  networking.hostName = "installer";

  # Enable flakes on the ISO
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Useful tools in the live environment
  environment.systemPackages = with pkgs; [
    git	
    tmux
    vim
    networkmanager
    exfatprogs
  ];

  # NetworkManager for WiFi
  networking.networkmanager.enable = true;
  # The installer profile may enable networking.wireless by default; disable it to avoid conflicts
  networking.wireless.enable = false;

  # SSH access (key-only)
  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # Add your SSH public key here (safe to store in repo)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA_REPLACE_ME_YOUR_PUBLIC_KEY"
  ];

  # ---- Ventoy: mount the data partition (exFAT, label "Ventoy") ----
  fileSystems."/mnt/ventoy" = {
    device = "/dev/disk/by-label/Ventoy";
    fsType = "exfat";
    options = [ "ro" "nofail" ];
  };

  # ---- sops-nix: use an age key that we copy from the Ventoy partition ----
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Installer secrets file (you already created this)
  sops.secrets.wifi_ssid = {
    sopsFile = ./secrets.yaml;
  };
  sops.secrets.wifi_psk = {
    sopsFile = ./secrets.yaml;
  };

  # Copy age key from Ventoy stick into place before sops-nix runs
  systemd.services.install-age-key = {
    description = "Install age key from Ventoy USB";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    before = [ "sops-nix.service"];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      
      install -d -m 0755 /var/lib/sops-nix

      # Expected location on the Ventoy exFAT partition:
      # /mnt/ventoy/keys/age.key
      if [ -f /mnt/ventoy/keys/age.key ]; then
        install -D -m 0400 /mnt/ventoy/keys/age.key /var/lib/sops-nix/key.txt
      else
        echo "WARNING: /mnt/ventoy/keys/age.key not found; WiFi secrets cannot be decrypted."
      fi
    '';
  };

  # Create a NetworkManager profile from decrypted secrets
  sops.templates."installer-wifi.nmconnection" = {
    owner = "root";
    group = "root";
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/installer-wifi.nmconnection";
    content = ''
      [connection]
      id=installer-wifi
      type=wifi
      autoconnect=true

      [wifi]
      mode=infrastructure
      ssid=${config.sops.placeholder.wifi_ssid}

      [wifi-security]
      key-mgmt=wpa-psk
      psk=${config.sops.placeholder.wifi_psk}

      [ipv4]
      method=auto

      [ipv6]
      method=auto
    '';
  };

  # Reload NetworkManager profiles after sops-nix has rendered the template
  systemd.services.nm-apply-installer-wifi = {
    description = "Reload NetworkManager and bring up installer WiFi";
    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" "sops-nix.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      ${pkgs.networkmanager}/bin/nmcli connection reload || true
      ${pkgs.networkmanager}/bin/nmcli connection up "installer-wifi" || true
      if [ -f /etc/NetworkManager/system-connections/installer-wifi.nmconnection ]; then
        ${pkgs.networkmanager}/bin/nmcli connection reload || true
        ${pkgs.networkmanager}/min/nmcli connection up "installer-wifi" || true
      else
        echo "WARNING: installer-wifi profile non found, skipping WiFi bring-up."
      fi
    '';
  };

  # Make sure we actually reach multi-user.target on the ISO
  systemd.defaultUnit = "multi-user.target";
}

