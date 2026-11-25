{ ... }:

{
  imports = [
    ../../modules/security/crowdsec.nix
  ];

  asgard.security.crowdsec = {
    enable = true;
    firewallBouncer = false;
  };
}