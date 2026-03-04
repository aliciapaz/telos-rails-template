#!/bin/bash
set -euo pipefail

echo "==> Initializing firewall rules..."

# ---------- helpers ---------------------------------------------------------

validate_cidr() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]
}

validate_ip() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ---------- preserve Docker DNS ---------------------------------------------

DOCKER_DNS_RULES=""
if iptables -t nat -S 2>/dev/null | grep -q "DOCKER"; then
  DOCKER_DNS_RULES=$(iptables -t nat -S | grep "DOCKER" || true)
fi

# ---------- flush existing rules --------------------------------------------

iptables -F
iptables -X 2>/dev/null || true
iptables -t nat -F
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F
iptables -t mangle -X 2>/dev/null || true
ipset destroy allowed-domains 2>/dev/null || true

# Restore Docker DNS rules
if [ -n "$DOCKER_DNS_RULES" ]; then
  echo "$DOCKER_DNS_RULES" | while read -r rule; do
    iptables -t nat ${rule/-A/-A} 2>/dev/null || true
  done
fi

# ---------- create ipset for allowed domains --------------------------------

ipset create allowed-domains hash:net

# ---------- GitHub IP ranges ------------------------------------------------

echo "==> Fetching GitHub IP ranges..."
GITHUB_META=$(curl -sf https://api.github.com/meta 2>/dev/null || echo "")

if [ -n "$GITHUB_META" ]; then
  GITHUB_CIDRS=$(echo "$GITHUB_META" | jq -r '
    [.hooks, .web, .api, .git, .packages, .pages, .actions, .dependabot, .copilot]
    | map(select(. != null))
    | flatten
    | map(select(test("^[0-9]")))
    | unique
    | .[]' 2>/dev/null || echo "")

  if [ -n "$GITHUB_CIDRS" ]; then
    AGGREGATED=$(echo "$GITHUB_CIDRS" | aggregate -q 2>/dev/null || echo "$GITHUB_CIDRS")
    while IFS= read -r cidr; do
      if validate_cidr "$cidr"; then
        ipset add allowed-domains "$cidr" 2>/dev/null || true
      fi
    done <<< "$AGGREGATED"
    echo "    GitHub IP ranges added."
  fi
else
  echo "    WARNING: Could not fetch GitHub IP ranges"
fi

# ---------- allowed domains -------------------------------------------------

ALLOWED_DOMAINS=(
  # Claude / Anthropic
  "api.anthropic.com"
  "claude.ai"
  "storage.googleapis.com"
  "statsig.anthropic.com"
  "statsig.com"
  "sentry.io"

  # Package registries
  "rubygems.org"
  "index.rubygems.org"
  "rubygems.pkg.github.com"

  # VS Code / devcontainer connectivity
  "marketplace.visualstudio.com"
  "vscode.blob.core.windows.net"
  "update.code.visualstudio.com"
)

echo "==> Resolving allowed domains..."
for domain in "${ALLOWED_DOMAINS[@]}"; do
  ips=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' || true)
  for ip in $ips; do
    if validate_ip "$ip"; then
      ipset add allowed-domains "$ip/32" 2>/dev/null || true
    fi
  done
done
echo "    Domain IPs resolved and added."

# ---------- detect host network ---------------------------------------------

HOST_NET=$(ip route | grep default | awk '{print $3}' | head -1)
HOST_SUBNET=""
if [ -n "$HOST_NET" ]; then
  HOST_SUBNET=$(ip route | grep -v default \
    | grep "$(ip route | grep default | awk '{print $5}' | head -1)" \
    | awk '{print $1}' | head -1)
  echo "    Host subnet detected as: ${HOST_SUBNET:-unknown}"
fi

# ---------- apply firewall rules -------------------------------------------

# Default policies: drop everything
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established / related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow host network (for Docker host services, database, etc.)
if [ -n "$HOST_SUBNET" ]; then
  iptables -A OUTPUT -d "$HOST_SUBNET" -j ACCEPT
  iptables -A INPUT -s "$HOST_SUBNET" -j ACCEPT
fi

# Allow HTTPS outbound to allowed destinations only
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-domains dst -j ACCEPT

# Reject everything else
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# ---------- verification ----------------------------------------------------

echo "==> Verifying firewall..."

if curl -sf --connect-timeout 3 https://example.com > /dev/null 2>&1; then
  echo "    WARNING: example.com is reachable (firewall may not be working)"
else
  echo "    OK: example.com is blocked"
fi

if curl -sf --connect-timeout 5 https://api.github.com > /dev/null 2>&1; then
  echo "    OK: api.github.com is reachable"
else
  echo "    WARNING: api.github.com is not reachable"
fi

echo "==> Firewall initialized."
