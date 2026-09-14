# modules/containers/mediamtx.nix
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
  options.apps.mediamtx = {
    enable = lib.mkEnableOption "MediaMTX";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open MediaMTX ports in the firewall.";
    };

    webrtcAdditionalHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional hosts advertised to WebRTC clients.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.mediamtx = {
      image = "docker.io/bluenviron/mediamtx@sha256:19fddade8d6110a3d718ac0045681fbeba344ae563a066205fe5929a87f7582f";

      ports = [
        "1935:1935/tcp"
        "8888:8888/tcp"
        "8889:8889/tcp"
        "8189:8189/udp"
      ];

      volumes = [
        "${mediamtxConfig}:/mediamtx.yml:ro"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        1935
        8888
        8889
      ];

      allowedUDPPorts = [
        8189
      ];
    };
  };
}