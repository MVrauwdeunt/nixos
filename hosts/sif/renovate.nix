{ ... }:
{
  apps.renovate = {
    enable = true;
    tokenEnvFile = "/run/secrets/renovate-env";
    configFile = "/run/secrets/renovate-config.js";
    endpoint = "http://127.0.0.1/api/v1/";
    repositories = [ "zanbee/nixos" ];
    logLevel = "info";
  };
}