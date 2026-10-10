{
  description = "Raylib Zig template development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.zig-overlay.url = "github:mitchellh/zig-overlay";

  outputs =
    {
      nixpkgs,
      zig-overlay,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
    in
    {
      devShells = forAllSystems (pkgs: system: {
        default = pkgs.mkShell {
          packages = [
            zig-overlay.packages.${system}."0.17.0"
          ];
          shellHook = ''
            unset NIX_LDFLAGS NIX_CFLAGS_COMPILE
          '';
        };
      });
    };
}
