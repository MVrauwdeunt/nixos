# modules/sops.nix
{ ... }:
{
  sops = {
    # Gebruik dezelfde centrale secrets file
    defaultSopsFile = ../secrets.yaml;
    validateSopsFiles = false;

    age = {
      # host SSH key als age key (handig op bv. Hetzner)
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # dedicated age key; wordt aangemaakt als hij nog niet bestaat
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    # /run/secrets/tailscaleAuthKey
    secrets.tailscaleAuthKey = {};
    # later kun je simpel extra secrets bijzetten:
    # secrets.ghToken = {};
  };
}
