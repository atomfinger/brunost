{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    zig = {
      url = "github:mitchellh/zig-overlay";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      systems = lib.systems.flakeExposed;
      pkgsFor = lib.genAttrs systems (system: import nixpkgs { inherit system; });
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
    in
    {

      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixd
            nixfmt
            statix

            zig
            mise
            python3
          ];
        };
      });

      packages = forEachSystem (pkgs: rec {
        brunost = pkgs.callPackage ./nix/package.nix { inherit inputs; };
        default = brunost;
      });
    };
}
