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
  sops.secrets."mimir/lidify/env" = {
    sopsFile = ../../secrets.yaml;
    path = "/var/lib/lidify/lidify.env";
    owner = "zanbee";
    group = "users";
    mode = "0400";
  };
  sops.secrets."mimir/gluetun/airvpn_env" = {
    sopsFile = ../../secrets.yaml;
    path = "/var/lib/gluetun/airvpn.env";
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."mimir/gluetun/auth_config" = {
    sopsFile = ../../secrets.yaml;
    path = "/var/lib/gluetun/auth/config.toml";
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."mimir/gluetun/control_env" = {
    sopsFile = ../../secrets.yaml;
    path = "/var/lib/gluetun/control.env";
    owner = "root";
    group = "root";
    mode = "0400";
  };
}
