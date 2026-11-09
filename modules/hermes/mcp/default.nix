
# modules/mcp/default.nix
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
        )
        (builtins.readDir serverDir)
    );

in
{
  imports =
    map (name: serverDir + "/${name}") serverFiles;
}
