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

# Verify WireMock CLI config exists on the host
WIREMOCK_CONFIG_DIR="${HOME}/.config/wiremock-cli"
if [ ! -f "${WIREMOCK_CONFIG_DIR}/config.yaml" ]; then
    echo "Error: WireMock CLI config not found at ${WIREMOCK_CONFIG_DIR}/config.yaml"
    echo "Log in to WireMock Cloud first: wiremock auth login"
    exit 1
fi

# Ensure host directories exist for bind mounts
mkdir -p "$HOME/.gradle" "$HOME/.m2"

# Check that bind-mounted directories are shared with Docker
UNSHARED_DIRS=()
for dir in "$HOME/.gradle" "$HOME/.m2" "$WIREMOCK_CONFIG_DIR"; do
    if ! docker run --rm -v "$dir:/mnt/test:ro" alpine true 2>/dev/null; then
        UNSHARED_DIRS+=("$dir")
    fi
done

if [ ${#UNSHARED_DIRS[@]} -gt 0 ]; then
    echo "Error: The following directories are not shared with Docker:"
    for dir in "${UNSHARED_DIRS[@]}"; do
        echo "  - $dir"
    done
    echo ""
    echo "In Docker Desktop, go to Settings > Resources > File Sharing and add these paths,"
    echo "or add their parent directory (e.g. $HOME)."
    exit 1
fi

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
