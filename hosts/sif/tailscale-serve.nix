{ pkgs, ... }:
{
  systemd.services.tailscale-serve-netalertx = {
    description = "Tailscale Serve for NetAlertX";
    after = [ "tailscaled.service" "podman-netalertx.service" ];
    wants = [ "tailscaled.service" "podman-netalertx.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ''
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:20211
      '';
      ExecStop = ''
        ${pkgs.tailscale}/bin/tailscale serve reset
      '';
    };
  };
}
