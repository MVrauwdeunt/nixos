
# modules/hermes/mcp/default.nix
#
# Globally available MCP servers.
# Home Assistant is reserved for LYRA.
# Allos is reserved for PULSE.

{ lib, ... }:

let
  serverDir = ./servers;

  privateServers = [
    "default.nix"
    "homeassistant.nix"
    "allos.nix"
  ];

  serverFiles =
    builtins.attrNames (
      lib.filterAttrs
        (name: type:
          type == "regular"
          && lib.hasSuffix ".nix" name
          && !(builtins.elem name privateServers)
        )
        (builtins.readDir serverDir)
    );

in
{
  imports =
    map (name: serverDir + "/${name}") serverFiles;

  # Explicitly disable profile-specific MCP servers globally.
  # Hermes/Nix preserves unmanaged keys in existing config.
  services.hermes-agent.settings.mcp_servers = {
    homeassistant.enabled = false;
    allos.enabled = false;
  };
}
