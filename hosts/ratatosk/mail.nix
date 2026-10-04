# hosts/ratatosk/mail.nix

{ config, ... }:

let
  mailDomain = "openmailbox.nl";
  mailHost = "ratatosk-test.openmailbox.nl";
in
{
  mailserver = {
    enable = true;
    stateVersion = 5;

    fqdn = mailHost;

    domains = [
      mailDomain
    ];

    systemContact = "postmaster@openmailbox.nl";

    x509.useACMEHost = mailHost;

    enableSubmission = true;
    openFirewall = true;

    accounts = {
      "m.vrauwdeunt@openmailbox.nl" = {
        passwordFile =
          config.sops.secrets."ratatosk/mail/m-vrauwdeunt-password".path;

        aliases = [
          "zanbee@openmailbox.nl"
          "postmaster@openmailbox.nl"
          "abuse@openmailbox.nl"
        ];
      };

      "paperless@openmailbox.nl" = {
        passwordFile =
          config.sops.secrets."ratatosk/mail/paperless-password".path;
      };

      "authelia@openmailbox.nl" = {
        passwordFile =
          config.sops.secrets."ratatosk/mail/authelia-password".path;

        sendOnly = true;
      };
    };

    dkim = {
      enable = true;

      domains."openmailbox.nl".selectors."ratatosk-2026" = {
        keyType = "rsa";
        keyLength = 2048;
      };
    };

    virusScanning = false;
  };
}