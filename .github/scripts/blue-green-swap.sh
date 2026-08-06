#!/usr/bin/env bash
# Usage: blue-green-swap.sh <project-slug> <repo-lower> <image-tag>
#
# Flow:
#   1. Pull new images from GHCR
#   2. Find a free port for new platform container
#   3. Start platform + background-worker simultaneously
#   4. Health check platform
#   5. Update nginx config with new port (reload nginx)
#   6. Stop + remove old containers
#   7. Rename new containers to canonical names
#   8. Prune old images
set -euo pipefail

SLUG="${1:?slug required}"
REPO="${2:?repo required}"
IMAGE_TAG="${3:?image-tag required}"

PLATFORM_IMAGE="ghcr.io/${REPO}/${SLUG}-platform:${IMAGE_TAG}"
WORKER_IMAGE="ghcr.io/${REPO}/${SLUG}-background-worker:${IMAGE_TAG}"

PLATFORM_CANONICAL="${SLUG}-platform"
WORKER_CANONICAL="${SLUG}-background-worker"
PLATFORM_NEW="${SLUG}-platform-new"
WORKER_NEW="${SLUG}-background-worker-new"

DEPLOY_DIR="/home/deploy/vyapti/generated-projects/${SLUG}"
ENV_FILE="${DEPLOY_DIR}/.env"
ENV_PORTS="${DEPLOY_DIR}/.env.ports"
HEALTH_PATH="${HEALTH_PATH:-/api/v1/vulcan/health-check}"

# ── 1. Pull new images ────────────────────────────────────────────────────
echo "[blue-green] Pulling images..." >&2
docker pull "$PLATFORM_IMAGE"
docker pull "$WORKER_IMAGE"

# ── 2. Find a free port ───────────────────────────────────────────────────
echo "[blue-green] Finding free port..." >&2
NEW_PORT=""
for PORT in $(seq 4000 6000); do
  if ss -tlnp | grep -q ":${PORT} "; then continue; fi
  NEW_PORT="$PORT"
  break
done
if [ -z "$NEW_PORT" ]; then
  echo "ERROR: no free port found in 4000-6000" >&2
  exit 1
fi
echo "[blue-green] New port: $NEW_PORT" >&2

# ── 3. Start both new containers simultaneously ───────────────────────────
echo "[blue-green] Starting new platform and background-worker together..." >&2
docker rm -f "$PLATFORM_NEW" "$WORKER_NEW" 2>/dev/null || true

docker run -d \
  --name "$PLATFORM_NEW" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  --env-file "$ENV_PORTS" \
  -p "${NEW_PORT}:3000" \
  "$PLATFORM_IMAGE"

docker run -d \
  --name "$WORKER_NEW" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  --env-file "$ENV_PORTS" \
  "$WORKER_IMAGE" \
  pnpm run worker:prod

# ── 4. Health check platform ──────────────────────────────────────────────
echo "[blue-green] Waiting 15s for containers to initialise..." >&2
sleep 15
RETRIES=15
INTERVAL=10
for i in $(seq 1 "$RETRIES"); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:${NEW_PORT}${HEALTH_PATH}" || true)
  if [ "$STATUS" = "200" ]; then
    echo "[blue-green] Health check passed on attempt ${i}" >&2
    break
  fi
  if [ "$i" = "$RETRIES" ]; then
    echo "ERROR: health check failed after $((RETRIES * INTERVAL))s — rolling back" >&2
    docker rm -f "$PLATFORM_NEW" 2>/dev/null || true
    docker rm -f "$WORKER_NEW"   2>/dev/null || true
    exit 1
  fi
  echo "[blue-green] Attempt ${i}/${RETRIES} — got ${STATUS}, retrying in ${INTERVAL}s..." >&2
  sleep "$INTERVAL"
done

# ── 5. Update nginx port only ─────────────────────────────────────────────
echo "[blue-green] Updating nginx..." >&2
DOMAIN="${SLUG}.v7ai.org"
CONF="/etc/nginx/sites-available/${DOMAIN}"

# Get current port from nginx config and swap just the port number
OLD_PORT=$(grep -oP '127\.0\.0\.1:\K[0-9]+' "$CONF" 2>/dev/null || echo "")

if [ -n "$OLD_PORT" ]; then
  sudo sed -i "s/127\.0\.0\.1:${OLD_PORT}/127.0.0.1:${NEW_PORT}/" "$CONF"
else
  # No existing config — write fresh one
  sudo tee "$CONF" > /dev/null << NGINX
server {
    listen 80;
    server_name ${DOMAIN};
    location / {
        proxy_pass         http://127.0.0.1:${NEW_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header   Connection        "";
        proxy_read_timeout 60s;
    }
}
NGINX
  sudo ln -sf "$CONF" "/etc/nginx/sites-enabled/${DOMAIN}"
fi

sudo nginx -t
sudo systemctl reload nginx
echo "[blue-green] nginx → 127.0.0.1:${NEW_PORT}" >&2

# ── 6. Remove old containers ──────────────────────────────────────────────
echo "[blue-green] Removing old containers..." >&2
docker stop "$PLATFORM_CANONICAL" 2>/dev/null || true
docker rm   "$PLATFORM_CANONICAL" 2>/dev/null || true
docker stop "$WORKER_CANONICAL"   2>/dev/null || true
docker rm   "$WORKER_CANONICAL"   2>/dev/null || true

# ── 7. Rename new → canonical ─────────────────────────────────────────────
echo "[blue-green] Renaming containers to canonical names..." >&2
docker rename "$PLATFORM_NEW" "$PLATFORM_CANONICAL"
docker rename "$WORKER_NEW"   "$WORKER_CANONICAL"

# ── 8. Prune old images ───────────────────────────────────────────────────
echo "[blue-green] Pruning old images..." >&2
docker image prune -af

echo "[blue-green] Done. ${SLUG} running on port ${NEW_PORT}" >&2