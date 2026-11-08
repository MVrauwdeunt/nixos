
{ config, lib, ... }:

let
  cfg = config.apps.soularr;
in
{
  imports = [
    (import ./common.nix {
      name = "soularr";
      image = "docker.io/mrusse08/soularr:v1.2.3@sha256:e448d49d0ca6091a35653ff9198ebb4a3acf42abfc2f2056490a9a0f0cffd210";
      port = 8265;
      tailscaleDefault = true;

      bindAddress = "0.0.0.0";
      configMount = "/data";
      usePuidPgid = false;
      extraOptions = [ "--user=1000:1000" ];
    })
  ];

  options.apps.soularr = {
    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Downloads/Muziek/soularr";
    };

    configSecretName = lib.mkOption {
      type = lib.types.str;
      default = "mimir/soularr/config_ini";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.soularr.volumes = lib.mkAfter [
      "${config.sops.secrets.${cfg.configSecretName}.path}:/data/config.ini:ro"
      "${cfg.downloadsDir}:/downloads"
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.downloadsDir} 0755 1000 1000 -"
      "d ${cfg.downloadsDir}/complete 0755 1000 1000 -"
      "d ${cfg.downloadsDir}/incomplete 0755 1000 1000 -"
      "d ${cfg.downloadsDir}/failed_imports 0755 1000 1000 -"
    ];
  };
}
