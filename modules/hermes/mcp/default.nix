
# modules/hermes/mcp/default.nix
#
# Globally available MCP servers.
# Home Assistant is reserved for LYRA.

{ lib, ... }:

let
  serverDir = ./servers;

  serverFiles =
    builtins.attrNames (
      lib.filterAttrs
        (name: type:
          type == "regular"
          && lib.hasSuffix ".nix" name
          && name != "default.nix"
          && name != "homeassistant.nix"
        )
        (builtins.readDir serverDir)
    );

in
{
  imports =
    map (name: serverDir + "/${name}") serverFiles;

  # Explicitly disable the previously global Home Assistant MCP.
  # Hermes/Nix preserves unmanaged keys in the existing config.
  services.hermes-agent.settings.mcp_servers.homeassistant.enabled = false;
}
