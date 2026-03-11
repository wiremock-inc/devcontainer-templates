#!/bin/bash
# Seeds Claude Code config files to skip the interactive onboarding flow
# and configure WireMock MCP server, Arazzo runner and WireMock skills plugin.

CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-/home/vscode/.claude}"
CLAUDE_JSON="${CLAUDE_CONFIG_DIR}/.claude.json"

mkdir -p "$CLAUDE_CONFIG_DIR"

# ~/.claude/settings.json - permissions and plugin config
if [ ! -f "$CLAUDE_CONFIG_DIR/settings.json" ]; then
    cat > "$CLAUDE_CONFIG_DIR/settings.json" << 'SETTINGS'
{
  "permissions": {
    "allow": [
      "mcp__wiremock__*",
      "mcp__arazzo-runner__*"
    ],
    "deny": []
  },
  "enabledPlugins": {
    "wiremock-cloud@wiremock-inc-skills": true
  },
  "extraKnownMarketplaces": {
    "wiremock-inc-skills": {
      "source": {
        "source": "github",
        "repo": "wiremock-inc/skills"
      }
    }
  }
}
SETTINGS
fi

# ~/.claude/.claude.json - global state (onboarding, API key approval, MCP servers)
CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "1.0.0")

KEY_SUFFIX=""
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    KEY_SUFFIX="${ANTHROPIC_API_KEY: -20}"
fi

if [ -f "$CLAUDE_JSON" ]; then
    # Merge onboarding keys and MCP server config into existing file using jq
    jq --arg ver "$CLAUDE_VERSION" --arg suffix "$KEY_SUFFIX" '
        .hasCompletedOnboarding = true |
        .lastOnboardingVersion = $ver |
        .autoUpdates = false |
        .hasSeenTasksHint = true |
        .customApiKeyResponses = {
            "approved": ((.customApiKeyResponses.approved // []) + [$suffix] | unique),
            "rejected": (.customApiKeyResponses.rejected // [])
        } |
        .projects."/workspace".hasTrustDialogAccepted = true |
        .mcpServers.wiremock = {
            "type": "stdio",
            "command": "wiremock",
            "args": ["mcp"],
            "env": {}
        } |
        .mcpServers."arazzo-runner" = {
            "type": "stdio",
            "command": "arazzo-runner",
            "args": ["mcp"],
            "env": {}
        }
    ' "$CLAUDE_JSON" > "${CLAUDE_JSON}.tmp" && mv "${CLAUDE_JSON}.tmp" "$CLAUDE_JSON"
else
    cat > "$CLAUDE_JSON" << EOF
{
  "numStartups": 1,
  "autoUpdates": false,
  "hasCompletedOnboarding": true,
  "lastOnboardingVersion": "${CLAUDE_VERSION}",
  "firstStartTime": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "installMethod": "global",
  "hasSeenTasksHint": true,
  "customApiKeyResponses": {
    "approved": ["${KEY_SUFFIX}"],
    "rejected": []
  },
  "projects": {
    "/workspace": {
      "hasTrustDialogAccepted": true
    }
  },
  "mcpServers": {
    "wiremock": {
      "type": "stdio",
      "command": "wiremock",
      "args": ["mcp"],
      "env": {}
    },
    "arazzo-runner": {
      "type": "stdio",
      "command": "arazzo-runner",
      "args": ["mcp"],
      "env": {}
    }
  }
}
EOF
fi
