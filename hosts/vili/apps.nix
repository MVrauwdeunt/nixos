
{ lib, ... }:

let
  enabledModules = [
    "hermes-agent"
    "signal-cli"
  ];

  enabledApps = [
    "open-webui"
    "litellm"
    "honcho"
  ];

  modules =
    map (name: ../../modules/${name}.nix) enabledModules;

  appModules =
    map (name: ../../modules/containers/${name}.nix) enabledApps;
in
{
  imports = modules ++ appModules;

  services.signalCli = {
    enable = true;
    httpPort = 8080;
  };

  apps = (lib.genAttrs enabledApps (_: {
    enable = true;
    openFirewall = false;
  })) // {
    open-webui = {
      enable = true;
      openFirewall = false;
      oidc.enable = true;
    };

    litellm = {
      enable = true;
      openFirewall = false;

      # Existing LiteLLM image from 2026-10-08.
      # Predates the 2026-10-21 security incident.
      image = "ghcr.io/berriai/litellm:main-stable@sha256:3d88bd757134a00e8c00237b85a021ab1f6d54abb9c1df750f411dbe7256a500";
    };

    honcho = {
      enable = true;
      openFirewall = false;

      # Honcho API and Deriver use the same image.
      # Existing image from 2026-10-16.
      image = "ghcr.io/plastic-labs/honcho:latest@sha256:50cc57c327210a694b3934fe8c3c090fca5b5f0271fe911e6a15ddc752928657";

      # PostgreSQL 15 with pgvector.
      # Existing image from 2026-10-01.
      postgresImage = "docker.io/pgvector/pgvector:pg15@sha256:47af0b65960b14f1c6945aa4ccae37836c632e9a6fe0eea9160936e616e5b2e9";

      # Redis 8.
      # Existing image from 2026-10-06.
      redisImage = "docker.io/library/redis:8@sha256:2c2dff791878316e3b083188be0d578423b24813cdda5de0e80ea4f7b3e6bfd6";
    };
  };
}
