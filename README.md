# WireMock Dev Container Templates

Reusable [Dev Container Templates](https://containers.dev/implementors/templates/) for running Claude Code in sandboxed environments.

## Available Templates

### Claude Code Sandbox (`claude-code`)

A sandboxed devcontainer for running Claude Code with firewall isolation, pre-configured for JVM/Kotlin projects.

**Includes:**
- Eclipse Temurin JDK (configurable version: 17, 21, 25)
- Node.js 20
- Claude Code CLI (latest)
- zsh with plugins (git, gradle, fzf)
- git-delta for better diffs
- iptables firewall restricting outbound traffic to whitelisted domains only

**Firewall allowlist:**
- Anthropic / Claude API
- GitHub (including IP ranges from the meta API)
- Package registries (Maven Central, Gradle Plugin Portal, npm)
- WireMock domains
- Docker registries

### Claude Code Sandbox with WireMock (`claude-code-wiremock`)

Everything in the base `claude-code` template, plus:

- **WireMock MCP server** - interact with WireMock Cloud mock APIs directly from Claude Code
- **Arazzo runner MCP server** - execute Arazzo workflow specifications against APIs
- **WireMock skills plugin** (`wiremock-inc/skills`) - pre-installed skills for building API simulations, creating stubs, stateful/data-driven mocking, and more

**Prerequisites:**
- WireMock CLI must be authenticated on the host (`wiremock auth login`). The host config at `~/.config/wiremock-cli/` is bind-mounted read-only into the container.

## Usage

### Option 1: Dev Containers CLI

Apply the template to your project:

```bash
devcontainer templates apply \
  --template-id ghcr.io/wiremock-inc/devcontainer-templates/claude-code \
  --workspace-folder .
```

This copies the `.devcontainer/` directory into your project.

### Option 2: Start script (recommended for CLI usage)

After applying the template, use the included start script:

```bash
# Start the devcontainer and launch Claude Code
./start-devcontainer.sh

# Rebuild from scratch
./start-devcontainer.sh --rebuild

# Pass args to Claude Code
./start-devcontainer.sh "fix the failing tests"
```

The start script:
1. Reads your `ANTHROPIC_API_KEY` from the macOS Keychain (Claude Code's stored credential) or the environment
2. Starts the devcontainer
3. Seeds Claude Code config to skip onboarding
4. Launches Claude Code with `--dangerously-skip-permissions`

### Option 3: VS Code / IntelliJ

1. Apply the template (Option 1 above)
2. Open the project in VS Code or IntelliJ
3. Use the "Reopen in Container" action

### Template Options

| Option | Description | Default |
|--------|-------------|---------|
| `javaVersion` | Java version (Eclipse Temurin JDK) | `17` |
| `timezone` | Container timezone | `Europe/London` |

## How It Works

The devcontainer runs with `NET_ADMIN` and `NET_RAW` capabilities to enable an iptables-based firewall. On container start, `init-firewall.sh` resolves allowed domains to IP addresses, creates an ipset allowlist, and applies default-deny iptables rules. Only DNS, SSH, and HTTP(S) traffic to whitelisted IPs is permitted.

Claude Code config is seeded on first launch to skip the interactive onboarding flow and trust dialog, so it starts immediately in coding mode.

Persistent Docker volumes are used for:
- Command history
- Claude Code configuration
- Gradle cache

## Publishing

Templates are automatically published to GHCR when changes are pushed to `main`, via the [devcontainers/action](https://github.com/devcontainers/action) GitHub Action.

## License

Apache License 2.0 - see [LICENSE](LICENSE).
