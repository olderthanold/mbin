#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web_1_cert_nginx.sh v02
#
# Purpose:
#   Obtain and configure an auto-renewable Let's Encrypt certificate for Nginx.
#
# Behavior:
#   1) Accept optional domain argument.
#      - If not provided, defaults to olderthanold.duckdns.org ("duck").
#   2) Check whether certificate files already exist for the domain.
#   3) If missing, request/install cert via certbot nginx plugin.
#   4) Test nginx config and test cert renewal flow.
#   5) Enable and start certbot.timer for automatic renewal.

DEFAULT_DOMAIN="olderthanold.duckdns.org"
DOMAIN="${1:-$DEFAULT_DOMAIN}"

# Retry tuning for transient certbot failures
MAX_RETRIES=5
BASE_DELAY_SECONDS=10
MAX_DELAY_SECONDS=120

is_fatal_certbot_error() {
  local log_file="$1"

  # Best-effort fatal classifiers (non-retriable in this script).
  # Notes:
  # - Matching is case-insensitive.
  # - Unknown failures are treated as transient and retried up to MAX_RETRIES.
  grep -Eiq \
    "(nxdomain|no valid ip addresses found|invalid identifier|rejectedidentifier|"\
"unable to find a virtual host listening on port 80|could not automatically find a matching server block|"\
"nginx: \[emerg\]|the nginx plugin is not working|failed authorization procedure|unauthorized|"\
"dns problem: nxdomain|too many certificates already issued for exact set of domains)" \
    "$log_file"
}

retry_certbot_command() {
  local label="$1"
  shift

  local attempt=1
  local rc=0
  local delay=0
  local log_file
  log_file="$(mktemp)"

  while (( attempt <= MAX_RETRIES )); do
    echo -e "${YELLOW}[$label] Attempt $attempt/$MAX_RETRIES${NC}"
    : > "$log_file"

    set +e
    "$@" >"$log_file" 2>&1
    rc=$?
    set -e

    if (( rc == 0 )); then
      cat "$log_file"
      rm -f "$log_file"
      return 0
    fi

    echo -e "${YELLOW}[$label] Command failed (exit $rc).${NC}"
    cat "$log_file"

    if is_fatal_certbot_error "$log_file"; then
      echo -e "${YELLOW}[$label] Fatal certbot error detected. Stopping without retry.${NC}"
      rm -f "$log_file"
      return "$rc"
    fi

    if (( attempt == MAX_RETRIES )); then
      echo -e "${YELLOW}[$label] Transient/unknown error persisted after $MAX_RETRIES attempts. Giving up.${NC}"
      rm -f "$log_file"
      return "$rc"
    fi

    delay=$(( BASE_DELAY_SECONDS * (2 ** (attempt - 1)) ))
    if (( delay > MAX_DELAY_SECONDS )); then
      delay=$MAX_DELAY_SECONDS
    fi

    echo -e "${YELLOW}[$label] Transient/unknown error. Retrying in ${delay}s...${NC}"
    sleep "$delay"
    attempt=$((attempt + 1))
  done

  rm -f "$log_file"
  return 1
}

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [domain]"
  echo "Example: $0"
  echo "Example: $0 example.com"
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

CERT_FULLCHAIN="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
CERT_PRIVKEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

echo -e "${YELLOW}Running web_1_cert_nginx.sh v02${NC}"
echo "Target domain: $DOMAIN"
echo -e "${YELLOW}[1/5] Ensuring certbot + nginx plugin are installed (this may take a while)...${NC}"
apt-get update -y
apt-get install -y certbot python3-certbot-nginx

echo -e "${YELLOW}[2/5] Checking whether certificate already exists for $DOMAIN...${NC}"
if [[ -f "$CERT_FULLCHAIN" && -f "$CERT_PRIVKEY" ]]; then
  echo -e "${YELLOW}Certificate files already exist for $DOMAIN. Skipping issuance.${NC}"
else
  echo -e "${YELLOW}Certificate not found. Requesting certificate via certbot...${NC}"
  retry_certbot_command "certbot-issue" certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    --redirect
fi

echo -e "${YELLOW}[3/5] Testing nginx configuration...${NC}"
nginx -t

echo -e "${YELLOW}[4/5] Enabling and starting auto-renew timer...${NC}"
systemctl enable --now certbot.timer
systemctl is-enabled certbot.timer >/dev/null && echo "certbot.timer is enabled"

echo -e "${YELLOW}[5/5] Testing renewal flow (dry-run)...${NC}"
retry_certbot_command "certbot-renew-dry-run" certbot renew --dry-run

echo -e "${GREEN}Done. Certificate workflow completed for: $DOMAIN${NC}"
echo "Tip: check next scheduled run with: systemctl list-timers | grep certbot"
