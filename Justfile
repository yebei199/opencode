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
    echo "==> 构建权威的 node_modules_updater derivation..."
    BUILD_LOG=$(mktemp)
    if HTTPS_PROXY="http://{{DEPLOY_SOCKS5_HOST}}:{{DEPLOY_SOCKS5_PORT}}" \
      HTTP_PROXY="http://{{DEPLOY_SOCKS5_HOST}}:{{DEPLOY_SOCKS5_PORT}}" \
      nix build .#node_modules_updater --no-link --print-build-logs --option substitute false \
      > "$BUILD_LOG" 2>&1; then
      echo "node_modules_updater unexpectedly succeeded; fakeHash may have been replaced."
      cat "$BUILD_LOG"
      exit 1
    fi
    HASH=$(grep 'got:' "$BUILD_LOG" | tail -1 | sed 's/.*got:[[:space:]]*//')
    if [ -z "$HASH" ]; then
      echo "failed to extract hash from node_modules_updater output"
      cat "$BUILD_LOG"
      exit 1
    fi
    echo ""
    echo "x86_64-linux hash: $HASH"
    echo ""
    echo "请将上面的 hash 填入 nix/hashes.json 的 x86_64-linux 字段"

[group('others')]
rm_sisyphus:
    mkdir -p .sisyphus docs/plans
    find .sisyphus -mindepth 1 -delete || true
    find docs/plans -mindepth 1 -delete || true
