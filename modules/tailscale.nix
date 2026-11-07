
# modules/tailscale.nix
{ config, lib, ... }:

let
  cfg = config.my.tailscale;

  advertisedTags = map (tag: "tag:${tag}") cfg.tags;

  tagFlags = lib.optionals (cfg.tags != []) [
    "--advertise-tags=${lib.concatStringsSep "," advertisedTags}"
  ];
in
{
  options.my.tailscale.tags = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = [ "server" "nixos" "vps" ];

    description = ''
      Tailscale tags assigned to this host.
      Specify tags without the "tag:" prefix.
    '';
  };

  config = {
    services.tailscale = {
      enable = lib.mkDefault true;

      # Authentication via SOPS
      authKeyFile =
        config.sops.secrets.tailscaleAuthKey.path;

      # Connection preferences and advertised tags
      extraUpFlags = lib.mkDefault (
        [ "--ssh" ] ++ tagFlags
      );

      # Firewall managed by the Tailscale NixOS module
      openFirewall = true;

      useRoutingFeatures = lib.mkDefault "server";
    };

    # Avoid unnecessary daemon restarts during deployments
    systemd.services.tailscaled.restartIfChanged = false;
  };
}
