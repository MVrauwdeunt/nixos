{ ... }:
{
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };
  
  sops.secrets."sif/renovate-env" = {
    sopsFile = ../../secrets.yaml;
    path = "/run/secrets/renovate-env";
  };

}
