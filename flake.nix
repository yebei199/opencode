# Compose the repo flake outputs and pin Bun consistently for Nix builds.
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
          ver = "1.3.13";
          srcs = {
            "aarch64-darwin" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-darwin-aarch64.zip";
              hash = "sha256-VGfj9l26Umuf6pjwzOBO+vwMY+Fpcz7Ce4dqOtMtoZA=";
            };
            "aarch64-linux" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-linux-aarch64.zip";
              hash = "sha256-cLrkGzkIsKEg4eWMXIrzDnSvrjuNEbDT/djnh937SyI=";
            };
            "x86_64-darwin" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-darwin-x64-baseline.zip";
              hash = "sha256-qYumpIDyL9qbNDYmuQak4mqlNhi/hdK8WSjs8rpF8O0=";
            };
            "x86_64-linux" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-linux-x64.zip";
              hash = "sha256-ecB3H6i5LDOq5B4VoODTB+qZ0OLwAxfHHGxTI3p44lo=";
            };
          };
          bun = prev.bun.overrideAttrs (_: {
            version = ver;
            src =
              srcs.${final.stdenvNoCC.hostPlatform.system}
                or (throw "Unsupported system: ${final.stdenvNoCC.hostPlatform.system}");
            passthru = prev.bun.passthru // {
              sources = srcs;
            };
            meta = prev.bun.meta // {
              changelog = "https://bun.sh/blog/bun-v${ver}";
            };
          });
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
          inherit bun;
          inherit node_modules_diagnose;
          inherit opencode;
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
