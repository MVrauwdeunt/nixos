{ config, lib, ... }:

{
  imports = [
    (import ./common.nix {
      name = "arr-dashboard";
      image = "docker.io/khak1s/arr-dashboard:2.24.1@sha256:bd24ff75a61708de22c31947ea8f7efbe1c44ea870c3af9eb0f021968c5d4bab";
      port = 3000;
      tailscaleDefault = true;

      bindAddress = "0.0.0.0";
    })
  ];

  options.apps.arr-dashboard.tailscale.serviceName = lib.mkOption {
    type = lib.types.str;
    default = "arr-dashboard";
    description = "Tailscale service name.";
  };

  config = lib.mkIf config.apps.arr-dashboard.enable (
    let
      publicHost = "${config.apps.arr-dashboard.tailscale.serviceName}.fiordland-gar.ts.net";
      publicUrl = "https://${publicHost}";
    in
    {
      virtualisation.oci-containers.containers.arr-dashboard.environment = {
        APP_URL = publicUrl;
        API_CORS_ORIGIN = publicUrl;
        WEBAUTHN_RP_NAME = "Arr Dashboard";
        WEBAUTHN_RP_ID = publicHost;
        WEBAUTHN_ORIGIN = publicUrl;
      };
    }
  );
}
