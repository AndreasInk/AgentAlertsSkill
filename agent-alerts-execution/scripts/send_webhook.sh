#!/bin/sh
set -eu

usage() {
  printf '%s\n' "Usage: send_webhook.sh [--check] PAYLOAD_JSON" >&2
}

check_only=false
if [ "${1:-}" = "--check" ]; then
  check_only=true
  shift
fi

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
  printf '%s\n' "AGENTALERTS_AGENT_TOKEN is unavailable." >&2
  exit 78
fi

if ! printf '%s' "$AGENTALERTS_AGENT_TOKEN" |
  jq -R -e 'test("^[A-Za-z0-9._-]+$")' >/dev/null; then
  printf '%s\n' "AGENTALERTS_AGENT_TOKEN has an invalid format." >&2
  exit 78
fi

if [ -z "${AGENTALERTS_WEBHOOK_URL:-}" ]; then
  printf '%s\n' "AGENTALERTS_WEBHOOK_URL is unavailable." >&2
  exit 78
fi

case "$AGENTALERTS_WEBHOOK_URL" in
  https://*[\?\#]*)
    printf '%s\n' "AGENTALERTS_WEBHOOK_URL must not contain a query or fragment." >&2
    exit 78
    ;;
  https://*) ;;
  *)
    printf '%s\n' "AGENTALERTS_WEBHOOK_URL must use HTTPS." >&2
    exit 78
    ;;
esac

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
    "$AGENTALERTS_WEBHOOK_URL"
