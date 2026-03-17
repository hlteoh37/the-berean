#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/ec2-user/the-berean"

# Load environment
if [ -f "${REPO_DIR}/.env" ]; then
    set -a
    source "${REPO_DIR}/.env"
    set +a
fi

export PATH="/home/ec2-user/.local/bin:/usr/local/bin:${PATH}"
LOG_DIR="${REPO_DIR}/state/logs"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_FILE="${LOG_DIR}/cycle-${TIMESTAMP}.log"

cd "${REPO_DIR}"
mkdir -p "${LOG_DIR}" state

echo "=== The Berean Cycle Starting: ${TIMESTAMP} ===" | tee "${LOG_FILE}"

# Run Claude Code CLI with the agent prompt
claude --print \
    --max-turns 20 \
    --allowedTools "Bash(git*),Bash(curl*),Bash(npx*),Bash(npm*),Bash(python3*),Bash(pip3*),Bash(cat*),Bash(mkdir*),Bash(cp*),Bash(mv*),Bash(ls*),Bash(echo*),Bash(date*),Bash(wc*),Read,Write,Edit,Glob,Grep" \
    -p "$(cat agent/prompt.md)" \
    2>&1 | tee -a "${LOG_FILE}"

echo "=== The Berean Cycle Complete: $(date -u +"%Y-%m-%dT%H:%M:%SZ") ===" | tee -a "${LOG_FILE}"
