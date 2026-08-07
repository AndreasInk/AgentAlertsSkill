#!/bin/sh
set -eu

usage() {
  printf '%s\n' "Usage: send_webhook.sh [--check|--check-config] PAYLOAD_JSON" >&2
}

check_only=false
check_config=false
case "${1:-}" in
  --check)
    check_only=true
    shift
    ;;
  --check-config)
    check_config=true
    shift
    ;;
esac

if [ "$#" -ne 1 ]; then
  usage
  exit 64
fi

payload_file=$1

if [ ! -r "$payload_file" ] || [ ! -f "$payload_file" ]; then
  printf '%s\n' "Agent Alerts payload is not a readable file." >&2
  exit 66
fi

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "Agent Alerts webhook send requires jq." >&2
  exit 69
fi

if ! jq -e '
  type == "object"
  and (.idempotency_key |
    type == "string"
    and length > 0
    and length <= 255
    and (explode | all(. >= 32 and . != 34 and . != 92 and . != 127))
  )
  and (
    if has("payload") then
      ((has("title") or has("summary") or has("status") or has("source_name") or has("deep_link")) | not)
    else
      (.title | type == "string" and length > 0 and length <= 32)
      and (.summary | type == "string" and length > 0 and length <= 96)
      and ((.status // "good") as $status | ["good", "warning", "critical"] | index($status) != null)
    end
  )
' "$payload_file" >/dev/null; then
  printf '%s\n' "Invalid Agent Alerts payload: require idempotency_key and either compact fields or a full payload, never both." >&2
  exit 65
fi

idempotency_key=$(jq -r '.idempotency_key' "$payload_file")

if [ "$check_only" = true ]; then
  printf '%s\n' "Agent Alerts payload is valid."
  exit 0
fi

if [ -z "${AGENTALERTS_AGENT_TOKEN:-}" ]; then
  token_file=${AGENTALERTS_TOKEN_FILE:-"${HOME:?}/.config/agent-alerts/token.env"}
  if [ -L "$token_file" ] || [ ! -f "$token_file" ] || [ ! -r "$token_file" ]; then
    printf '%s\n' "AGENTALERTS_AGENT_TOKEN is unavailable." >&2
    exit 78
  fi

  if token_mode=$(stat -f '%Lp' "$token_file" 2>/dev/null) &&
    token_owner=$(stat -f '%u' "$token_file" 2>/dev/null); then
    :
  elif token_mode=$(stat -c '%a' "$token_file" 2>/dev/null) &&
    token_owner=$(stat -c '%u' "$token_file" 2>/dev/null); then
    :
  else
    printf '%s\n' "Unable to verify Agent Alerts token file permissions." >&2
    exit 78
  fi
  if [ "$token_owner" != "$(id -u)" ]; then
    printf '%s\n' "Agent Alerts token file must be owned by the current user." >&2
    exit 78
  fi
  case "$token_mode" in
    600) ;;
    *)
      printf '%s\n' "Agent Alerts token file must have mode 0600." >&2
      exit 78
      ;;
  esac

  if ! AGENTALERTS_AGENT_TOKEN=$(awk '
    /^[[:space:]]*(#.*)?$/ { next }
    /^AGENTALERTS_AGENT_TOKEN=[A-Za-z0-9._-]+$/ {
      if (found) exit 2
      sub(/^AGENTALERTS_AGENT_TOKEN=/, "")
      print
      found = 1
      next
    }
    { exit 3 }
    END { if (!found) exit 4 }
  ' "$token_file"); then
    printf '%s\n' "Agent Alerts token file must contain exactly one AGENTALERTS_AGENT_TOKEN assignment." >&2
    exit 78
  fi
fi

if ! printf '%s' "$AGENTALERTS_AGENT_TOKEN" |
  jq -R -e 'test("^[A-Za-z0-9._-]+$")' >/dev/null; then
  printf '%s\n' "AGENTALERTS_AGENT_TOKEN has an invalid format." >&2
  exit 78
fi

if [ -n "${AGENTALERTS_WEBHOOK_URL:-}" ]; then
  printf '%s\n' "The bundled Agent Alerts helper does not accept a custom webhook destination." >&2
  exit 78
fi

if [ "$check_config" = true ]; then
  printf '%s\n' "Agent Alerts payload and configuration are valid."
  exit 0
fi

if [ ! -x /usr/bin/curl ]; then
  printf '%s\n' "Agent Alerts webhook send requires /usr/bin/curl." >&2
  exit 69
fi

printf 'header = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\nheader = "Idempotency-Key: %s"\n' \
  "$AGENTALERTS_AGENT_TOKEN" "$idempotency_key" |
  /usr/bin/curl \
    --config - \
    --silent \
    --show-error \
    --fail-with-body \
    --retry 1 \
    --retry-delay 1 \
    --retry-connrefused \
    --request POST \
    --data-binary "@$payload_file" \
    "https://www.andreas.ink/api/agent"
