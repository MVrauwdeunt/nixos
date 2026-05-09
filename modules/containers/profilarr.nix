virtualisation.oci-containers.containers.profilarr = {
  image = "docker.io/santiagosayshey/profilarr:latest";

  ports = [
    "127.0.0.1:${toString cfg.port}:6868"
  ];

  volumes = [
    "${cfg.dataDir}:/config"
  ];

  environment = {
    PUID = "1000";
    PGID = "1000";
    UMASK = "022";
    TZ = "Europe/Amsterdam";
  };

  extraOptions = [
    "--network=bridge"
    "--health-cmd=none"
  ];
};