#!/usr/bin/env bash
# Usage: find-port.sh <slug> <service>
# Assigns (or reuses) a free host port in 4000-6000 for slug+service.
# Port map persists at /etc/v7ai/port-map — same port reused on every redeploy.
set -euo pipefail
SLUG="${1:?slug required}"
SERVICE="${2:?service required}"
PORT_MAP="/etc/v7ai/port-map"

sudo mkdir -p /etc/v7ai
sudo touch "$PORT_MAP"

KEY="${SLUG}.${SERVICE}"

EXISTING=$(sudo grep "^${KEY}=" "$PORT_MAP" 2>/dev/null | cut -d= -f2 || true)
if [[ -n "$EXISTING" ]]; then
  echo "[port] $KEY already assigned → $EXISTING" >&2
  echo "$EXISTING"
  exit 0
fi

for PORT in $(seq 4000 6000); do
  if sudo grep -q "=${PORT}$" "$PORT_MAP" 2>/dev/null; then continue; fi
  if ss -tlnp | grep -q ":${PORT} "; then continue; fi
  echo "${KEY}=${PORT}" | sudo tee -a "$PORT_MAP" > /dev/null
  echo "[port] $KEY → $PORT (newly assigned)" >&2
  echo "$PORT"
  exit 0
done

echo "ERROR: no free port found in 4000-6000" >&2
exit 1