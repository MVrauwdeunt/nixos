{ lib, ... }:

let
  dir = ./.;

  files = builtins.attrNames (builtins.readDir dir);

  containerFiles =
    builtins.filter
      (name:
        name != "default.nix"
        && lib.hasSuffix ".nix" name)
      files;

  containerNames =
    map (name: lib.removeSuffix ".nix" name) containerFiles;

  mkContainerImports = name: [
    ../../../modules/containers/${name}.nix
    ./${name}.nix
  ];
in
{
  imports = builtins.concatLists (map mkContainerImports containerNames);
}