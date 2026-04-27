# Compose the repo flake outputs for Nix builds.
{
  description = "OpenCode development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      overlay =
        final: prev:
        let
          node_modules = final.callPackage ./nix/node_modules.nix {
            inherit rev;
          };
          node_modules_diagnose = final.callPackage ./nix/node_modules-diagnose.nix {
            inherit rev;
          };
          opencode = final.callPackage ./nix/opencode.nix {
            inherit node_modules;
          };
          desktop = final.callPackage ./nix/desktop.nix {
            inherit opencode;
          };
        in
        {
          inherit node_modules_diagnose opencode;
          opencode-desktop = desktop;
        };
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ overlay ];
            }
          )
        );
      rev = self.shortRev or self.dirtyShortRev or "dirty";
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            nodejs_20
            pkg-config
            openssl
            git
          ];
        };
      });

      overlays = {
        default = overlay;
      };

      packages = forEachSystem (pkgs: {
        default = pkgs.opencode;
        inherit (pkgs) opencode;
        desktop = pkgs.opencode-desktop;
        inherit (pkgs) node_modules_diagnose;
        # Updater derivation with fakeHash - build fails and reveals correct hash
        node_modules_updater = pkgs.opencode.node_modules.override {
          hash = pkgs.lib.fakeHash;
        };
      });
    };
}
