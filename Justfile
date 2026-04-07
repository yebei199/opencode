set shell := ["fish", "-c"]
set dotenv-load := true
set export := true

# 本地 SOCKS5 代理默认配置（127.0.0.1:7897）

DEPLOY_SOCKS5_HOST := env_var_or_default("DEPLOY_SOCKS5_HOST", "127.0.0.1")
DEPLOY_SOCKS5_PORT := env_var_or_default("DEPLOY_SOCKS5_PORT", "7897")


[group('others')]
rm_sisyphus:
    mkdir -p .sisyphus docs/plans
    find .sisyphus -mindepth 1 -delete || true
    find docs/plans -mindepth 1 -delete || true


