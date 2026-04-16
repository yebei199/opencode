# 该文件统一组装开发环境与 Nix 派生，并在仓库内覆盖 Bun 版本以保持构建链路一致。
{
  description = "OpenCode development flake";

  # 个人分支：硬编码本机代理，加速 Nix 守护进程自身的网络请求（fetchurl 等）
  nixConfig = {
    http-proxy = "http://127.0.0.1:7897";
    https-proxy = "http://127.0.0.1:7897";
  };

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
          ver = "1.3.11";
          srcs = {
            "aarch64-darwin" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-darwin-aarch64.zip";
              hash = "sha256-b1o0Z+2crsR5W/eM1HZQfZ+HDH1XuGyUX8szgSZ3L/w=";
            };
            "aarch64-linux" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-linux-aarch64.zip";
              hash = "sha256-0TlE2hKlPsx0v2pyC9HQTEVVwDjf5CI2U1anvkdpH98=";
            };
            "x86_64-darwin" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-darwin-x64-baseline.zip";
              hash = "sha256-+2c5sIv1RVDtqnyCTNWy3KRbagav70CEQwh6YxBfb40=";
            };
            "x86_64-linux" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${ver}/bun-linux-x64.zip";
              hash = "sha256-hhG6k1r4hvBabzh0ChUWAybBXl1dB63vlmEwtEk2B+0=";
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
          opencode = final.callPackage ./nix/opencode.nix {
            inherit node_modules;
          };
          desktop = final.callPackage ./nix/desktop.nix {
            inherit opencode;
          };
        in
        {
          inherit bun;
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
        # Updater derivation with fakeHash - build fails and reveals correct hash
        node_modules_updater = pkgs.opencode.node_modules.override {
          hash = pkgs.lib.fakeHash;
        };
      });
    };
}
