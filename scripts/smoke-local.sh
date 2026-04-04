#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "[smoke] Subindo WireMock..."
docker compose up -d wiremock

echo "[smoke] Aguardando endpoint..."
for i in {1..20}; do
  if curl -fsS "http://localhost:8080/__admin" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[smoke] Executando testes..."
npm run test:smoke

echo "[smoke] Derrubando WireMock..."
docker compose down
