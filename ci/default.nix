
let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.nixosConfigurations.brokkr.pkgs;
in
import ./image.nix {
  inherit pkgs;
}
