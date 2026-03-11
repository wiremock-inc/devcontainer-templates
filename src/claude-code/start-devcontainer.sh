#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v devcontainer &> /dev/null; then
    echo "Error: devcontainer CLI not found. Install it with: npm install -g @devcontainers/cli"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo "Error: Docker is not running."
    exit 1
fi

# Resolve ANTHROPIC_API_KEY from Claude Code's macOS Keychain entry if not already set
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    ANTHROPIC_API_KEY=$(security find-generic-password -s "Claude Code" -w 2>/dev/null) || true
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "Error: ANTHROPIC_API_KEY not found."
    echo "Log in to Claude Code on the host first, or set the variable manually:"
    echo "  export ANTHROPIC_API_KEY=sk-ant-..."
    exit 1
fi

export ANTHROPIC_API_KEY

# Parse args: --rebuild is for devcontainer, everything else is for claude
REBUILD=false
CLAUDE_ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--rebuild" ]; then
        REBUILD=true
    else
        CLAUDE_ARGS+=("$arg")
    fi
done

echo "Starting devcontainer..."
if $REBUILD; then
    devcontainer up --workspace-folder "$SCRIPT_DIR" --remove-existing-container
else
    devcontainer up --workspace-folder "$SCRIPT_DIR"
fi

# Get the container ID
CONTAINER_ID=$(docker ps --filter "label=devcontainer.local_folder=$SCRIPT_DIR" --format '{{.ID}}' | head -1)

if [ -z "$CONTAINER_ID" ]; then
    echo "Error: Could not find running devcontainer."
    exit 1
fi

# Seed Claude Code config inside the container to skip interactive onboarding.
docker exec -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" "$CONTAINER_ID" \
    bash /workspace/.devcontainer/init-claude-config.sh

echo ""
echo "Launching Claude Code..."
docker exec -it -w /workspace -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" "$CONTAINER_ID" \
    claude --dangerously-skip-permissions ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}
