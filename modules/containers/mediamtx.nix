
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.mediamtx;

  additionalHosts =
    lib.concatMapStringsSep "\n"
      (host: "  - ${host}")
      cfg.webrtcAdditionalHosts;

  mediamtxConfig = pkgs.writeText "mediamtx.yml" ''
    rtmp: yes
    rtmpAddress: :1935

    hls: yes
    hlsAddress: :8888
    hlsAlwaysRemux: yes

    webrtc: yes
    webrtcAddress: :8889
    webrtcLocalUDPAddress: :8189
    ${lib.optionalString (cfg.webrtcAdditionalHosts != [ ]) ''
    webrtcAdditionalHosts:
    ${additionalHosts}
    ''}

    paths:
      drone:
        source: publisher

      action5:
        source: publisher
  '';
in
{
  imports = [
    (import ./common.nix {
      name = "mediamtx";

      image = "docker.io/bluenviron/mediamtx:1.21.2@sha256:c7540465f868a02652118bea5a0daab12a29ac0f6cb8485abd535939ecddf886";

      port = 1935;

      publishedPorts = [
        "1935:1935/tcp"
        "8888:8888/tcp"
        "8889:8889/tcp"
        "8189:8189/udp"
      ];

      mountConfig = false;
      createDataDir = false;
      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = [
        "${mediamtxConfig}:/mediamtx.yml:ro"
      ];
    })
  ];

  options.apps.mediamtx.webrtcAdditionalHosts = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Additional hosts advertised to WebRTC clients.";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        8888
        8889
      ];

      allowedUDPPorts = [
        8189
      ];
    };
  };
}
