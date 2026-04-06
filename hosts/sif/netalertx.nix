{ ... }:
{
  # --------------------------------------------------
  # NetAlertX
  # --------------------------------------------------
  apps.netalertx = {
    enable = true;

    dataDir = "/var/lib/netalertx";

    uid = 20211;
    gid = 20211;

    timezone = "Europe/Amsterdam";

    port = 20211;
    graphqlPort = 20212;

    openFirewall = false;
  };
}
