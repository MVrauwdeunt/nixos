{ config, pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # VM-friendly
  services.qemuGuest.enable = true;
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net" ];

  time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = true;

  # QoL
  environment.systemPackages = [ pkgs.kitty.terminfo ];
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  # Bash QoL (interactive only)
  programs.bash = {
    enable = true;
    interactiveShellInit = ''
      # Enable autocd so typing a directory name jumps into it
      shopt -s autocd

      # Append to history instead of overwriting
      shopt -s histappend

      # Recursive globbing with **
      shopt -s globstar

      # Update LINES/COLUMNS after terminal resize
      shopt -s checkwinsize
    '';
  };


  # SSH (details hardening in aparte module)
  services.openssh.enable = true;

  # NIET zomaar verhogen op bestaande hosts
  system.stateVersion = "25.05";
}
