{ config, pkgs, lib, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # VM-friendly
  services.qemuGuest.enable = true;

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "virtio_net"
  ];

  boot.kernelPackages = lib.mkIf (lib.versionOlder pkgs.linux.version "6.18.22") (
    lib.mkDefault pkgs.linuxPackages_6_18
  );

  # Do not force-import ZFS root pools
  boot.zfs.forceImportRoot = false;

  time.timeZone = "Europe/Amsterdam";

  networking.firewall.enable = true;

  # Quality of life
  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  # Bash quality of life
  programs.bash = {
    completion.enable = true;

    # Interactive shells such as desktop terminals and interactive SSH sessions
    interactiveShellInit = ''
      # Only apply to interactive shells
      case $- in
        *i*)
          # Enable autocd so typing a directory name jumps into it
          shopt -s autocd

          # Append to history instead of overwriting
          shopt -s histappend

          # Recursive globbing with **
          shopt -s globstar

          # Update LINES/COLUMNS after terminal resize
          shopt -s checkwinsize
          ;;
      esac
    '';

    # Login shells such as many SSH sessions do not always read /etc/bashrc automatically
    loginShellInit = ''
      # Only apply to interactive shells
      case $- in
        *i*)
          if [ -f /etc/bashrc ]; then
            . /etc/bashrc
          fi
          ;;
      esac
    '';
  };

  # SSH hardening is configured in a separate module
  services.openssh.enable = true;

  # Do not increase this on existing hosts without a migration plan
  system.stateVersion = "25.05";
}