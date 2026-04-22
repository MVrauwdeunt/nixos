{ ... }:
{
  apps.renovate = {
    enable = true;
    tokenEnvFile = "/run/secrets/renovate-env";
    configFile = "/run/secrets/renovate-config.js";
    endpoint = "http://192.168.178.150/api/v1/";
    repositories = [ "zanbee/nixos" ];
    logLevel = "info";
  };
}