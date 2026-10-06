{ ... }:

{
  services.automx2 = {
    enable = true;
    domain = "openmailbox.nl";

    settings = {
      provider = "Openmailbox";

      domains = [
        "openmailbox.nl"
      ];

      servers = [
        {
          type = "imap";
          name = "ratatosk.openmailbox.nl";
        }
        {
          type = "smtp";
          name = "ratatosk.openmailbox.nl";
        }
      ];
    };
  };
}