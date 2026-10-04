# hosts/ratatosk/nginx.nix

{ ... }:

let
  mailHost = "ratatosk-test.openmailbox.nl";
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "postmaster@openmailbox.nl";
  };

  services.nginx = {
    enable = true;

    virtualHosts.${mailHost} = {
      enableACME = true;
    };
  };
}