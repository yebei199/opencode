set shell := ["fish", "-c"]
set dotenv-load := true
set export := true

# 本地 SOCKS5 代理默认配置（127.0.0.1:7897）

DEPLOY_SOCKS5_HOST := env_var_or_default("DEPLOY_SOCKS5_HOST", "127.0.0.1")
DEPLOY_SOCKS5_PORT := env_var_or_default("DEPLOY_SOCKS5_PORT", "7897")


# 本地计算 x86_64-linux 的 node_modules NAR hash，用于更新 nix/hashes.json
compute-hash:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}"
    echo "==> 清理 nix filter 覆盖的 node_modules（确保与 sandbox 一致）..."
    rm -rf node_modules \
      packages/opencode/node_modules \
      packages/desktop/node_modules \
      packages/app/node_modules \
      packages/shared/node_modules
    echo "==> bun install (--ignore-scripts --frozen-lockfile)..."
    HTTPS_PROXY="http://{{DEPLOY_SOCKS5_HOST}}:{{DEPLOY_SOCKS5_PORT}}" \
    HTTP_PROXY="http://{{DEPLOY_SOCKS5_HOST}}:{{DEPLOY_SOCKS5_PORT}}" \
    bun install \
      --cpu="x64" \
      --os="linux" \
      --filter '!./' \
      --filter './packages/opencode' \
      --filter './packages/desktop' \
      --filter './packages/app' \
      --filter './packages/shared' \
      --frozen-lockfile \
      --ignore-scripts \
      --no-progress
    echo "==> canonicalize-node-modules..."
    bun --bun nix/scripts/canonicalize-node-modules.ts
    echo "==> normalize-bun-binaries..."
    bun --bun nix/scripts/normalize-bun-binaries.ts
    echo "==> 只收集 filter 范围内的 node_modules（与 nix sandbox 一致）..."
    OUTDIR=$(mktemp -d)
    for pkg in . packages/opencode packages/desktop packages/app packages/shared; do
      if [ -d "$pkg/node_modules" ]; then
        cp -R --parents "$pkg/node_modules" "$OUTDIR"
      fi
    done
    echo "==> 计算 NAR hash..."
    HASH=$(nix hash path --sri "$OUTDIR")
    echo ""
    echo "x86_64-linux hash: $HASH"
    echo ""
    echo "请将上面的 hash 填入 nix/hashes.json 的 x86_64-linux 字段"

[group('others')]
rm_sisyphus:
    mkdir -p .sisyphus docs/plans
    find .sisyphus -mindepth 1 -delete || true
    find docs/plans -mindepth 1 -delete || true


