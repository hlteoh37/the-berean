#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Load environment
if [ -f "${REPO_DIR}/.env" ]; then
    set -a
    source "${REPO_DIR}/.env"
    set +a
fi

cd "$(dirname "$0")"

# Install dependencies if needed
pip3 install --user -q -r requirements.txt 2>/dev/null

# Start the server
python3 server.py
