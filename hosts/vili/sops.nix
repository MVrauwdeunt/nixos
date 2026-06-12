{ ... }:
{
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };

  sops.secrets."vili/hermes/env" = {
    sopsFile = ../../secrets.yaml;
  };
}