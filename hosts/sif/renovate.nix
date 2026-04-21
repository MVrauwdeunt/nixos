{ ... }:
{
  apps.renovate = {
    enable = true;
    tokenEnvFile = "/run/secrets/renovate-env";
    configFile = "/run/secrets/renovate-config.js";
    endpoint = "https://forgejo.fiordland-gar.ts.net/api/v1/";
    repositories = [ "zanbee/nixos" ];
    logLevel = "info";
  };
}