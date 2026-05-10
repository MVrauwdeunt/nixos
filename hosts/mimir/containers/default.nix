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
    "lidify.nix"
    "profilarr.nix"
    "newtarr.nix"
  ];
  
  mkContainerImports = name: [
    ../../../modules/containers/${name}.nix
    ./${name}.nix
  ];

in
{
  imports = builtins.concatLists (map mkContainerImports containers);
}