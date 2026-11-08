{ config, lib, ... }:
let cfg = config.apps.forgejo;
in {
  imports = [ (import ./common.nix {
    name = "forgejo";
    image = cfg.image;
    port = 3000;
    publishedPorts = [
      "127.0.0.1:${toString cfg.port}:${toString cfg.port}"
      "127.0.0.1:${toString cfg.sshPort}:${toString cfg.sshPort}"
    ];
    dataDir = "/var/lib/forgejo";
    configMount = "/data";
    directoryOwner = "root";
    directoryGroup = "root";
    tailscaleDefault = true;
    useTimezone = false;
    usePuidPgid = false;
    bridgeNetwork = false;
    disableHealthcheck = false;
    environment = {
      FORGEJO__server__ROOT_URL = cfg.appUrl;
      FORGEJO__server__START_SSH_SERVER = "true";
      FORGEJO__server__SSH_DOMAIN = cfg.sshDomain;
      FORGEJO__server__SSH_PORT = toString cfg.sshPort;
      FORGEJO__server__SSH_LISTEN_PORT = toString cfg.sshPort;
    };
    extraOptions = [ "--hostname=forgejo" "--userns=host" ];
  }) ];

  options.apps.forgejo = {
    image = lib.mkOption {
      type = lib.types.str;
      default = "codeberg.org/forgejo/forgejo:17.0.0@sha256:06d38310de496a10186d952bdad5ca764c153c8023ede8dfa0944c79a1dc5412";
    };
    sshPort = lib.mkOption { type = lib.types.port; default = 2222; };
    tailscale.tcpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 2222 ];
    };
    appUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://forgejo.fiordland-gar.ts.net";
    };
    sshDomain = lib.mkOption {
      type = lib.types.str;
      default = "forgejo.fiordland-gar.ts.net";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.forgejo.autoStart = true;
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.sshPort ];
    systemd.services.podman-forgejo = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
