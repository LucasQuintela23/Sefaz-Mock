#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export SEFAZ_API_URL="http://127.0.0.1:18080"

echo "[smoke-node] Subindo mock server local..."
node scripts/mock-sefaz-server.js &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "[smoke-node] Aguardando health endpoint..."
for i in {1..20}; do
  if curl -fsS "http://127.0.0.1:18080/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[smoke-node] Executando smoke tests..."
npm run test:smoke

echo "[smoke-node] Fluxo concluido."
