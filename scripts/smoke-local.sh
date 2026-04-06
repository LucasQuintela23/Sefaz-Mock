#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIREMOCK_PORT="${WIREMOCK_PORT:-18080}"

cd "$ROOT_DIR"

export SEFAZ_API_URL="http://127.0.0.1:${WIREMOCK_PORT}"

echo "[smoke] Gerando matriz e mappings do WireMock..."
npm run matrix:generate >/dev/null
npm run wiremock:mappings:generate >/dev/null

echo "[smoke] Subindo WireMock..."
docker compose up -d wiremock

echo "[smoke] Aguardando endpoint..."
for i in {1..20}; do
  if curl -fsS "http://127.0.0.1:${WIREMOCK_PORT}/__admin" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[smoke] Executando testes..."
npm run test:smoke

echo "[smoke] Derrubando WireMock..."
docker compose down
