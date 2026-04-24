{ ... }:
{
  apps.renovate = {
    enable = true;
    tokenEnvFile = "/run/secrets/renovate-env";
    repositories = [ "zanbee/nixos" ];
    logLevel = "debug";
  };
}