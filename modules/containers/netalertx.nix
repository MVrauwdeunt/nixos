{ config, lib, ... }:
let cfg = config.apps.netalertx;
in {
  imports = [ (import ./common.nix {
    name = "netalertx";
    image = cfg.image;
    port = 20211;
    publishedPorts = [ ];
    dataDir = "/var/lib/netalertx";
    createDataDir = false;
    mountConfig = false;
    tailscaleDefault = true;
    useTimezone = false;
    usePuidPgid = false;
    bridgeNetwork = false;
    disableHealthcheck = false;
    extraVolumes = [ "${cfg.dataDir}:/data" "/etc/localtime:/etc/localtime:ro" ];
    environment = {
      TZ = cfg.timezone;
      PUID = toString cfg.uid;
      PGID = toString cfg.gid;
      PORT = toString cfg.port;
      GRAPHQL_PORT = toString cfg.graphqlPort;
      ALWAYS_FRESH_INSTALL = "false";
      NETALERTX_DEBUG = toString cfg.debug;
    };
    extraOptions = [
      "--network=host" "--hostname=netalertx" "--userns=host"
      "--cap-drop=ALL" "--cap-add=NET_ADMIN" "--cap-add=NET_RAW"
      "--cap-add=NET_BIND_SERVICE" "--cap-add=CHOWN"
      "--cap-add=SETUID" "--cap-add=SETGID"
      "--tmpfs=/tmp:rw,noexec,nosuid,size=64m"
      "--tmpfs=/run:rw,noexec,nosuid,size=16m"
      "--memory=2048m" "--memory-reservation=1024m"
      "--cpus=0.5" "--pids-limit=512"
      "--security-opt=no-new-privileges"
    ];
  }) ];

  options.apps.netalertx = {
    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/jokob-sk/netalertx:26.10.24@sha256:df3fd09ac057c944d669b7fd819652ed87f0abae8e30e0cc24260ac34ebabb39";
    };
    uid = lib.mkOption { type = lib.types.int; default = 20211; };
    gid = lib.mkOption { type = lib.types.int; default = 20211; };
    timezone = lib.mkOption { type = lib.types.str; default = "Europe/Amsterdam"; };
    graphqlPort = lib.mkOption { type = lib.types.port; default = 20212; };
    debug = lib.mkOption { type = lib.types.int; default = 0; };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/db 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/config 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "f ${cfg.dataDir}/config/app.conf 0644 ${toString cfg.uid} ${toString cfg.gid} - -"
    ];
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.graphqlPort ];
    systemd.services.podman-netalertx = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
