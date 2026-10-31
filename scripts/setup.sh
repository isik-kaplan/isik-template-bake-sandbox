#!/usr/bin/env bash
# Writes .env for local development or a real deployment. Generation already ran it once; rerun it
# to switch a checkout to a deployment.
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".env"
EXAMPLE_FILE=".env.example"
PREFIX="TEST_PROJECT"

if [ -f "$ENV_FILE" ]; then
  if [ -t 0 ]; then
    read -r -p "$ENV_FILE already exists - overwrite it? [y/N] " overwrite
    case "$overwrite" in
      y|Y) ;;
      *) echo "Leaving $ENV_FILE as-is."; exit 0 ;;
    esac
  else
    # Never overwrite silently.
    exit 0
  fi
fi

cp "$EXAMPLE_FILE" "$ENV_FILE"

if [ ! -t 0 ]; then
  # No terminal to prompt on; .env.example's values already work for local development.
  exit 0
fi

echo
echo "Set up Test Project for:"
echo "  1) local development - .env.example's values already work, nothing else to decide"
echo "  2) a real deployment - generates strong secrets and asks for real configuration"
read -r -p "Choice [1]: " mode
mode="${mode:-1}"

if [ "$mode" != "2" ]; then
  echo "Wrote $ENV_FILE for local development."
  exit 0
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found - can't generate strong secrets. Install it and rerun this script." >&2
  exit 1
fi

# Sets KEY in .env, commented out or not, appending it if absent. Python, not sed: a value may hold & or /.
set_var() {
  python3 - "$1" "$2" <<'PY'
import re
import sys

key, value = sys.argv[1], sys.argv[2]
text = open(".env").read()
pattern = re.compile(rf"^#?{re.escape(key)}=.*$", re.MULTILINE)
replacement = f"{key}={value}"
if pattern.search(text):
    # A function, not the string itself: re.sub reads backslashes in a replacement string as escapes.
    text = pattern.sub(lambda _: replacement, text, count=1)
else:
    text = text.rstrip("\n") + f"\n{replacement}\n"
open(".env", "w").write(text)
PY
}

random_hex() {
  openssl rand -hex "${1:-32}"
}

ask() {
  local prompt="$1" default="$2" reply
  read -r -p "$prompt [$default]: " reply
  echo "${reply:-$default}"
}

ask_secret() {
  local prompt="$1" reply
  read -r -s -p "$prompt (leave blank to skip): " reply
  echo >&2
  echo "$reply"
}

echo
echo "Generating secrets..."
set_var "${PREFIX}__DEBUG" "false"
set_var "${PREFIX}__SECRET_KEY" "$(random_hex 32)"
# A Fernet key: 32 random bytes, url-safe base64.
set_var "${PREFIX}__CREDENTIAL_KEY" "$(openssl rand -base64 32 | tr '+/' '-_')"
set_var "${PREFIX}__DB__PASSWORD" "$(random_hex 24)"
set_var "${PREFIX}__BROKER__PASSWORD" "$(random_hex 24)"
set_var "${PREFIX}__CACHE__PASSWORD" "$(random_hex 24)"
set_var "${PREFIX}__FRONTEND_KEY" "$(random_hex 32)"

superuser_password="$(random_hex 16)"
set_var "${PREFIX}__SETUP__SUPERUSER__PASSWORD" "$superuser_password"

domain="$(ask "Domain this deploys to" "testproject.test")"
set_var "${PREFIX}__DOMAIN" "$domain"

echo
echo "nginx serves plain HTTP here, behind the TLS-terminating load balancer you put in front of it."
echo "Every proxy in that chain has to append to X-Forwarded-For, not replace it."
front_proxies="$(ask "How many proxies sit in front of nginx" "1")"
if ! [[ "$front_proxies" =~ ^[0-9]+$ ]]; then
  echo "Expected a whole number, got '$front_proxies'." >&2
  exit 1
fi
# nginx appends too, so it counts as one more.
set_var "${PREFIX}__TRUSTED_PROXY_COUNT" "$((front_proxies + 1))"

superuser_username="$(ask "Superuser username" "admin")"
set_var "${PREFIX}__SETUP__SUPERUSER__USERNAME" "$superuser_username"

superuser_email="$(ask "Superuser email" "admin@${domain}")"
set_var "${PREFIX}__SETUP__SUPERUSER__EMAIL" "$superuser_email"

echo
echo "DEBUG=false switches email from console to real SMTP - needed for password reset and"
echo "verification links to actually go anywhere."
smtp_host="$(ask "SMTP host" "")"
if [ -n "$smtp_host" ]; then
  set_var "${PREFIX}__EMAIL__SMTP__HOST" "$smtp_host"
  set_var "${PREFIX}__EMAIL__SMTP__PORT" "$(ask "SMTP port" "587")"
  set_var "${PREFIX}__EMAIL__SMTP__USER" "$(ask "SMTP username" "")"
  set_var "${PREFIX}__EMAIL__SMTP__PASSWORD" "$(ask_secret "SMTP password")"
  set_var "${PREFIX}__EMAIL__DEFAULT_FROM" "$(ask "Default from address" "noreply@${domain}")"
else
  echo "Skipped - fill in ${PREFIX}__EMAIL__SMTP__* in $ENV_FILE yourself before going live, or no email will send."
fi

# The bundled Garage takes the key it is given: GK and 24 hex digits, with a 64-hex-digit secret.
use_bundled_storage() {
  set_var "${PREFIX}__STORAGE__ACCESS_KEY_ID" "GK$(random_hex 12)"
  set_var "${PREFIX}__STORAGE__SECRET_ACCESS_KEY" "$(random_hex 32)"
  set_var "${PREFIX}__STORAGE__RPC_SECRET" "$(random_hex 32)"
  # Only the test suite makes buckets; a deployment's key reads and writes its own.
  set_var "${PREFIX}__STORAGE__KEY_CAN_CREATE_BUCKETS" "false"
}
use_bundled_storage

echo
social_login_providers="$(ask "Social login providers, as comma-separated allauth ids (blank for none)" "")"
if [ -n "$social_login_providers" ]; then
  set_var "${PREFIX}__SOCIAL_LOGIN__PROVIDERS" "$social_login_providers"
  echo "Their credentials (leave blank to configure later - that provider's button just won't"
  echo "complete its flow until you do):"
  # The list comes in on fd 3: the prompts inside the loop need stdin, or they would read the list.
  while IFS= read -r provider <&3; do
    [ -z "$provider" ] && continue
    key="$(echo "$provider" | tr '[:lower:]' '[:upper:]')"
    client_id="$(ask "  $provider client ID" "")"
    if [ -n "$client_id" ]; then
      set_var "${PREFIX}__OAUTH__${key}__CLIENT_ID" "$client_id"
      set_var "${PREFIX}__OAUTH__${key}__CLIENT_SECRET" "$(ask_secret "  $provider client secret")"
    fi
  done 3<<< "$(echo "$social_login_providers" | tr ',' '\n' | tr -d ' ')"
  if echo ",$social_login_providers," | tr -d ' ' | grep -q ",openid_connect,"; then
    echo "  openid_connect also needs ${PREFIX}__OAUTH__OPENID_CONNECT__SERVER_URL and"
    echo "  ...__PROVIDER_ID - set those in $ENV_FILE directly."
  fi
fi

echo
oauth_provider_mode="$(ask "Let other apps sign their users in with this project? off, approval (a superuser approves each app) or auto" "off")"
set_var "${PREFIX}__OAUTH_PROVIDER__MODE" "$oauth_provider_mode"
if [ "$oauth_provider_mode" != "off" ]; then
  # A .env value is one line, so line breaks are written \n, which the backend reads back.
  set_var "${PREFIX}__OAUTH_PROVIDER__SIGNING_KEY" \
    "$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null | awk '{printf "%s\\n", $0}')"
fi

echo
sentry_dsn="$(ask "Backend Sentry DSN" "")"
[ -n "$sentry_dsn" ] && set_var "${PREFIX}__SENTRY__DSN" "$sentry_dsn"

frontend_sentry_dsn="$(ask "Frontend (browser) Sentry DSN" "")"
[ -n "$frontend_sentry_dsn" ] && set_var "NEXT_PUBLIC_SENTRY_DSN" "$frontend_sentry_dsn"

echo
echo "Wrote $ENV_FILE for a real deployment."
echo "Superuser: $superuser_username / $superuser_password - save this, it's only shown once."
echo
echo "This template's nginx (test_project-server/) serves plain HTTP only - put"
echo "a TLS-terminating load balancer or reverse proxy in front of it before going live."
