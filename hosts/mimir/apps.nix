{ lib, ... }:

let
  enabledApps = [
    "seerr"
    "prowlarr"
    "radarr"
    "sonarr"
    "bazarr"
    "lidarr"
    "sabnzbd"
    "soularr"
    "slskd"
    "lidify"
    "profilarr"
    "newtarr"
    "gluetun"
  ];

  specialApps = [
    "jellyfin"
    "mediamtx"
  ];

  appModules =
    map (name: ../../modules/containers/${name}.nix)
      (enabledApps ++ specialApps);

in
{
  imports = appModules;

  apps =
    lib.genAttrs enabledApps (_: {
      enable = true;
      openFirewall = false;
    })
    // {
      jellyfin = {
        enable = true;
        openFirewall = false;
        dataDir = "/var/lib/jellyfin";
        mediaDir = "/mnt/shares/Media";
        enableHardwareAcceleration = true;
      };

      mediamtx = {
        enable = true;
        openFirewall = true;

        webrtcAdditionalHosts = [
          "100.68.37.68"
        ];
      };
    };
}