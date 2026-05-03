{ ... }:
{
  sops.secrets."sif/tailscale" = {
    sopsFile = ../../secrets.yaml;
  };

  sops.secrets."mimir/soularr/config_ini" = {
    sopsFile = ../../secrets.yaml;
    path = "/var/lib/soularr/config.ini";
    owner = "zanbee";
    group = "users";
    mode = "0400";
  };

}
