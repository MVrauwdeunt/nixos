{ ... }:
{
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };

  sops.secrets."mimir/soularr/config.ini" = {
    sopsFile = ../../secrets.yaml;
    path = "/var/lib/soularr/config.ini";
    owner = "1000";
    group = "1000";
    mode = "0400";
  };

}
