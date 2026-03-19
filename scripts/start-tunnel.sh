#!/usr/bin/env bash
# Start Cloudflare tunnel and update the tunnel URL in the site config.
# Called by cron keepalive and agent run.sh.
set -euo pipefail

REPO_DIR="/home/ec2-user/the-berean"
TUNNEL_LOG="${REPO_DIR}/state/logs/cloudflared.log"
TUNNEL_URL_FILE="${REPO_DIR}/docs/tunnel-url.json"
export PATH="/home/ec2-user/.local/bin:/home/ec2-user/.npm-global/bin:${PATH}"

# Check if tunnel is already running
if pgrep -f cloudflared > /dev/null 2>&1; then
    # Tunnel running — verify URL file exists
    if [ -f "$TUNNEL_URL_FILE" ]; then
        exit 0
    fi
fi

# Kill any stale tunnel
pkill -f cloudflared 2>/dev/null || true
sleep 1

# Start new tunnel
mkdir -p "$(dirname "$TUNNEL_LOG")"
nohup /home/ec2-user/.local/bin/cloudflared tunnel --url http://localhost:5001 > "$TUNNEL_LOG" 2>&1 &

# Wait for tunnel URL to appear
for i in $(seq 1 15); do
    sleep 2
    URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
    if [ -n "$URL" ]; then
        echo "{\"url\": \"${URL}\"}" > "$TUNNEL_URL_FILE"
        echo "Tunnel started: $URL"

        # Deploy via GitHub Pages — commit and push docs/
        cd "$REPO_DIR"
        git add docs/tunnel-url.json
        git commit -m "chore: update tunnel URL" 2>/dev/null || true
        git push origin main 2>/dev/null || true
        exit 0
    fi
done

echo "ERROR: Tunnel failed to start within 30 seconds"
exit 1
