# hosts/ratatosk/default.nix

{ config, inputs, lib, ... }:

let
  mailDomain = "openmailbox.nl";

  # Temporary hostname while Mail-in-a-Box still uses box.openmailbox.nl.
  # Change this to box.openmailbox.nl during the final migration.
  mailHost = "ratatosk-test.openmailbox.nl";
in
{
  imports = [
    ../../modules/users/zanbee
    inputs.nixos-mailserver.nixosModules.default
  ];

  nix.settings.trusted-users = [
    "root"
    "zanbee"
  ];

  apps.beszel-agent.enable = true;

  # Ratatosk is not an exit node.
  services.tailscale.extraUpFlags = lib.mkForce [
    "--advertise-tags=tag:nixos"
    "--ssh"
  ];

  services.tailscale.useRoutingFeatures = lib.mkForce "client";

  sops.secrets."ratatosk/mail/m-vrauwdeunt-password" = { };
  sops.secrets."ratatosk/mail/paperless-password" = { };
  sops.secrets."ratatosk/mail/authelia-password" = { };

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

  networking.firewall.allowedTCPPorts = [
    80
  ];

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