#!/usr/bin/env bash
set -euo pipefail
cd ~/the-berean
source .env
export PATH="/home/ec2-user/.local/bin:${PATH}"
mkdir -p state/logs
cd backend
exec python3 server.py >> ~/the-berean/state/logs/berean-backend.log 2>&1
