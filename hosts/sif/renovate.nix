{ ... }:
{
  apps.renovate = {
    enable = true;
    endpoint = "https://forgejo.fiordland-gar.ts.net/api/v1/";
    repositories = [ "zanbee/nixos" ];
    logLevel = "info";
  };
}