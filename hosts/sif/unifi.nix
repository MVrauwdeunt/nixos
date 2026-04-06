{ ... }:
{
  # --------------------------------------------------
  # UniFi
  # --------------------------------------------------
  apps.unifi = {
    enable = true;

    dataDir = "/var/lib/unifi";

    uid = 1000;
    gid = 1000;

    timezone = "Europe/Amsterdam";

    image = "lscr.io/linuxserver/unifi-network-application:10.1.89";
    mongoImage = "docker.io/mongo:8.0";

    mongoUser = "unifi";
    mongoPassword = "vervang-dit-met-een-goed-wachtwoord";
  };

  systemd.services.podman-unifi.after = [ "network-online.target" "podman-unifi-db.service" ];
  systemd.services.podman-unifi.wants = [ "network-online.target" ];
  systemd.services.podman-unifi.requires = [ "podman-unifi-db.service" ];

  systemd.services.podman-unifi-db.after = [ "network-online.target" ];
  systemd.services.podman-unifi-db.wants = [ "network-online.target" ];
}
