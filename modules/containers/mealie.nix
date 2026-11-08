
{ config, lib, ... }:

let
  cfg = config.apps.mealie;
in
{
  imports = [
    (import ./common.nix {
      name = "mealie";

      image = "ghcr.io/mealie-recipes/mealie:v3.29.0@sha256:78eb28b8776d0bad40c5e605c72b3f4f5976793e491558c7dcbdfc04c835d4bc";

      port = 9000;
      bindAddress = "127.0.0.1";
      configMount = "/app/data";

      tailscaleDefault = true;

      # Behoud de oorspronkelijke Podman-instellingen.
      bridgeNetwork = false;
      disableHealthcheck = false;

      environment = {
        ALLOW_SIGNUP = "false";
        BASE_URL = "https://mealie.gladsheimr.nl";
      };
    })
  ];

  config = lib.mkIf cfg.enable {
    sops.secrets."saga/mealie_openai_api_key" = {};

    sops.templates."mealie.env".content = ''
      OPENAI_API_KEY=${config.sops.placeholder."saga/mealie_openai_api_key"}
    '';

    virtualisation.oci-containers.containers.mealie.environmentFiles = [
      config.sops.templates."mealie.env".path
    ];
  };
}
