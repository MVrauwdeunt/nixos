{ ... }:
{
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };
  
  sops.secrets."sif/renovate-env" = {
    sopsFile = ../../secrets.yaml;
    path = "/run/secrets/renovate-env";
  };

  sops.secrets."sif/renovate-config" = {
    sopsFile = ../../secrets.yaml;
    path = "/run/secrets/renovate-config.js";
  };  
}
