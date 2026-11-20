
# modules/hermes/mcp/default.nix

{ lib, ... }:

let
  serverDir = ./servers;

  # Profile-specific MCP servers are configured in profiles.nix.
  profileSpecificServers = [
    "default.nix"
    "homeassistant.nix"
    "homelable.nix"
  ];

  serverFiles =
    builtins.attrNames (
      lib.filterAttrs
        (name: type:
          type == "regular"
          && lib.hasSuffix ".nix" name
          && !(builtins.elem name profileSpecificServers)
        )
        (builtins.readDir serverDir)
    );

in
{
  imports =
    map (name: serverDir + "/${name}") serverFiles;

  # Prevent the default NYX profile from loading these MCPs.
  services.hermes-agent.settings.mcp_servers = {
    homeassistant.enabled = false;
    homelable.enabled = false;
  };
}
