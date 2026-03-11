#!/bin/bash
# Firewall initialization script for Claude Code devcontainer
# Restricts outbound network access to only whitelisted domains
set -uo pipefail

echo "Initializing firewall rules..."

# Returns 0 for valid IPv4 CIDR, 1 otherwise (silent)
is_valid_ipv4_cidr() {
    [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]
}

# Returns 0 for valid IPv4 address, 1 otherwise (silent)
is_valid_ipv4() {
    [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

add_ip() {
    if is_valid_ipv4 "$1"; then
        ipset add allowed-domains "$1/32" 2>/dev/null || true
    fi
}

add_cidr() {
    if is_valid_ipv4_cidr "$1"; then
        ipset add allowed-domains "$1" 2>/dev/null || true
    fi
}

# Preserve Docker DNS rules before flushing
DOCKER_DNS_RULES=$(iptables-save | grep -E "DOCKER|docker|172\.17\." || true)

# Flush existing rules
iptables -F OUTPUT
iptables -F INPUT
iptables -F FORWARD

# Create ipset for allowed domains
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

# ---- Resolve and add allowed domains ----

ALLOWED_DOMAINS=(
    # Anthropic / Claude API
    "api.anthropic.com"
    "claude.ai"
    "console.anthropic.com"
    "statsigapi.net"
    "sentry.io"

    # Package registries
    "registry.npmjs.org"
    "plugins.gradle.org"
    "repo.maven.apache.org"
    "repo1.maven.org"
    "jcenter.bintray.com"
    "dl.google.com"
    "services.gradle.org"

    # GitHub
    "github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "github-cloud.githubusercontent.com"
    "ghcr.io"

    # VS Code / Dev Containers
    "update.code.visualstudio.com"
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "az764295.vo.msecnd.net"
    "openvsxorg.blob.core.windows.net"

    # WireMock
    "api.wiremock.cloud"
    "app.wiremock.cloud"
    "docs.wiremock.io"
    "www.wiremock.io"
    "wiremock.org"

    # Docker registries
    "registry-1.docker.io"
    "auth.docker.io"
    "production.cloudflare.docker.com"
)

echo "Resolving allowed domains..."
for domain in "${ALLOWED_DOMAINS[@]}"; do
    for ip in $(dig +short A "$domain" 2>/dev/null); do
        add_ip "$ip"
    done
done

# Fetch GitHub IP ranges from their meta API
echo "Fetching GitHub IP ranges..."
GH_META=$(curl -fsSL https://api.github.com/meta 2>/dev/null || echo "{}")
for key in hooks web git packages pages importer actions dependabot; do
    for cidr in $(echo "$GH_META" | jq -r ".${key}[]? // empty" 2>/dev/null || true); do
        add_cidr "$cidr"
    done
done

# Detect host/Docker network and allow local traffic
HOST_NETWORK=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "${HOST_NETWORK:-}" ]; then
    HOST_SUBNET=$(echo "$HOST_NETWORK" | sed 's/\.[0-9]*$/.0\/16/')
    add_cidr "$HOST_SUBNET"
fi

# Allow standard private networks for Docker and local services
ipset add allowed-domains "10.0.0.0/8" 2>/dev/null || true
ipset add allowed-domains "172.16.0.0/12" 2>/dev/null || true
ipset add allowed-domains "192.168.0.0/16" 2>/dev/null || true

# ---- Apply firewall rules ----

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (UDP and TCP port 53)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow SSH outbound (for git over SSH)
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTPS and HTTP to whitelisted IPs only
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -m set --match-set allowed-domains dst -j ACCEPT

# Allow other common ports to whitelisted IPs
iptables -A OUTPUT -p tcp --dport 8080 -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -p tcp --dport 8443 -m set --match-set allowed-domains dst -j ACCEPT

# Default deny outbound
iptables -A OUTPUT -p tcp -j DROP
iptables -A OUTPUT -p udp -j DROP

echo "Firewall rules applied."

# ---- Verify firewall ----
echo "Verifying firewall configuration..."

if curl -sf --connect-timeout 3 https://example.com > /dev/null 2>&1; then
    echo "WARN: example.com should be blocked but is reachable"
else
    echo "OK: Blocked domains are unreachable"
fi

if curl -sf --connect-timeout 5 https://api.github.com > /dev/null 2>&1; then
    echo "OK: Allowed domains are reachable"
else
    echo "WARN: api.github.com should be reachable but is not"
fi

echo "Firewall initialization complete."
