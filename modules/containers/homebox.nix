
{ config, lib, ... }:

let
  cfg = config.apps.homebox;

  defaultImage =
    "ghcr.io/sysadminsmedia/homebox:0.27.1-rootless";
in
{
  imports = [
    (import ./common.nix {
      name = "homebox";
      image = cfg.image;

      port = 3100;
      containerPort = 7745;
      bindAddress = "127.0.0.1";

      dataDir = "/var/lib/homebox";
      configMount = "/data";

      tailscaleDefault = true;

      directoryMode = "0750";
      directoryOwner = "65532";
      directoryGroup = "65532";

      usePuidPgid = false;

      environment = {
        HBOX_MODE = "production";
        HBOX_LOG_LEVEL = "info";
        HBOX_LOG_FORMAT = "text";
        HBOX_OPTIONS_ALLOW_ANALYTICS = "false";
      };

      extraOptions = [
        "--security-opt=no-new-privileges"
      ];
    })
  ];

  options.apps.homebox.image = lib.mkOption {
    type = lib.types.str;
    default = defaultImage;
    description = "Homebox container image.";
  };

  config = lib.mkIf cfg.enable {
    # Store the API key pepper in SOPS.
    sops.secrets."sif/homebox_api_key_pepper" = {
      sopsFile = ../../secrets.yaml;
    };

    # Generate the runtime environment file securely.
    sops.templates."homebox.env" = {
      mode = "0400";

      content = ''
        HBOX_AUTH_API_KEY_PEPPER=${config.sops.placeholder."sif/homebox_api_key_pepper"}
      '';
    };

    # Inject secrets at runtime without exposing them
    # in the Nix store.
    virtualisation.oci-containers.containers.homebox = {
      environmentFiles = [
        config.sops.templates."homebox.env".path
      ];
    };
  };
}
