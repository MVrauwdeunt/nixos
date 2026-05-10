{ ... }:

let
  containers = [
    "jellyfin"
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
  ];
  
  mkContainerImports = name: [
    ../../../modules/containers/${name}.nix
    ./${name}.nix
  ];

in
{
  imports = builtins.concatLists (map mkContainerImports containers);
}