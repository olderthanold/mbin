#!/usr/bin/env bash
# bai1_build_nginx_proxy.sh v02
set -euo pipefail

# Configures nginx aliases for the llama router:
# - public port 1234 -> llama backend
# - optional domain /llama/ -> llama backend

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN="${1:-}"
BACKEND_URL="${LLAMA_BACKEND_URL:-http://127.0.0.1:8080}"
SNIPPET_PATH="${SNIPPET_PATH:-/etc/nginx/snippets/llama-router-proxy.conf}"
PORT_ALIAS_CONF="${PORT_ALIAS_CONF:-/etc/nginx/conf.d/llama-router-1234.conf}"

show_help() {
  cat <<EOF
Usage: sudo bash $0 [domain]

Environment:
  LLAMA_BACKEND_URL   Default: http://127.0.0.1:8080

Behavior:
  - Always writes nginx listener for public port 1234.
  - If domain is provided and /etc/nginx/sites-available/<domain> exists,
    idempotently includes /llama/ proxy snippet in that site config.
EOF
}

if [[ "${DOMAIN}" == "-h" || "${DOMAIN}" == "--help" ]]; then
  show_help
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo -e "${RED}ERROR: sudo not found in PATH.${NC}"
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo -e "${RED}ERROR: nginx not found in PATH.${NC}"
  exit 1
fi

echo -e "${YELLOW}Running bai1_build_nginx_proxy.sh v02${NC}"
echo "Backend URL: ${BACKEND_URL}"

echo -e "${YELLOW}[1/4] Writing nginx /llama/ proxy snippet...${NC}"
sudo mkdir -p "$(dirname "${SNIPPET_PATH}")" "$(dirname "${PORT_ALIAS_CONF}")"
sudo tee "${SNIPPET_PATH}" >/dev/null <<EOF_SNIPPET
location /llama/ {
    proxy_pass ${BACKEND_URL%/}/;
    proxy_http_version 1.1;

    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;

    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    send_timeout 3600;
    client_max_body_size 64m;

    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
}
EOF_SNIPPET

echo -e "${YELLOW}[2/4] Writing nginx public port 1234 alias...${NC}"
sudo tee "${PORT_ALIAS_CONF}" >/dev/null <<EOF_PORT
server {
    listen 1234;
    listen [::]:1234;
    server_name _;

    location / {
        proxy_pass ${BACKEND_URL%/}/;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        send_timeout 3600;
        client_max_body_size 64m;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF_PORT

echo -e "${YELLOW}[3/4] Optionally wiring domain /llama/ route...${NC}"
if [[ -n "${DOMAIN}" ]]; then
  site_path="/etc/nginx/sites-available/${DOMAIN}"
  include_line="    include ${SNIPPET_PATH};"

  if [[ ! -f "${site_path}" ]]; then
    echo -e "${YELLOW}Domain nginx site not found, skipping domain include:${NC} ${site_path}"
  elif grep -Fq "${SNIPPET_PATH}" "${site_path}"; then
    echo "Domain site already includes llama proxy snippet: ${site_path}"
  else
    tmp_file="$(mktemp)"
    awk -v include_line="${include_line}" '
      { lines[NR] = $0 }
      END {
        last_close = 0
        for (i = 1; i <= NR; i++) {
          if (lines[i] ~ /^}/) {
            last_close = i
          }
        }
        for (i = 1; i <= NR; i++) {
          if (i == last_close) {
            print include_line
          }
          print lines[i]
        }
      }
    ' "${site_path}" > "${tmp_file}"
    sudo install -m 0644 "${tmp_file}" "${site_path}"
    rm -f "${tmp_file}"
    echo "Added llama proxy include to: ${site_path}"
  fi
else
  echo "No domain provided; only port 1234 alias was configured."
fi

echo -e "${YELLOW}[4/4] Testing and reloading nginx...${NC}"
sudo nginx -t
sudo systemctl reload nginx

echo -e "${GREEN}Done. nginx routes are configured.${NC}"
echo "Public API alias: http://<public-ip>:1234/v1"
if [[ -n "${DOMAIN}" ]]; then
  echo "Domain API alias: https://${DOMAIN}/llama/v1"
fi
