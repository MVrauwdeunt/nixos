{ ... }:
{
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };
}
