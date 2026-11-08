
{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "mazanoke";

      image = "ghcr.io/civilblur/mazanoke:v1.1.7@sha256:ca83cddd90cd1e4b43102884bf39025731a1c7569f3bbda9d6530de72528cbab";

      port = 3474;
      containerPort = 80;
      bindAddress = "0.0.0.0";

      tailscaleDefault = true;

      # De oorspronkelijke module heeft geen datamount.
      mountConfig = false;
      createDataDir = false;

      # Geen extra environmentvariabelen toevoegen.
      useTimezone = false;
      usePuidPgid = false;
    })
  ];
}
