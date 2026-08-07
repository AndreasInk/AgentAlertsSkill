#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
sender="$script_dir/send_webhook.sh"
example="$skill_dir/assets/compact-webhook-payload.json"
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT HUP INT TERM

expect_failure() {
  expected_status=$1
  shift
  set +e
  "$@" >/dev/null 2>&1
  actual_status=$?
  set -e
  if [ "$actual_status" -ne "$expected_status" ]; then
    printf 'Expected status %s, received %s: %s\n' \
      "$expected_status" "$actual_status" "$*" >&2
    exit 1
  fi
}

sh -n "$sender"
"$sender" --check "$example" >/dev/null

if ! grep -F 'https://www.andreas.ink/api/agent' "$sender" >/dev/null; then
  printf '%s\n' "Agent Alerts helper must remain pinned to the first-party endpoint." >&2
  exit 1
fi

if grep -E 'supabase\.co|github\.com/.*/(blob|raw)' "$sender" >/dev/null; then
  printf '%s\n' "Agent Alerts helper must not expose an infrastructure or source URL." >&2
  exit 1
fi

jq 'del(.idempotency_key)' "$example" >"$fixture_dir/missing-idempotency.json"
expect_failure 65 "$sender" --check "$fixture_dir/missing-idempotency.json"

jq '. + {"payload": {"title": "Mixed"}}' "$example" >"$fixture_dir/mixed-mode.json"
expect_failure 65 "$sender" --check "$fixture_dir/mixed-mode.json"

jq '.status = "unknown"' "$example" >"$fixture_dir/invalid-status.json"
expect_failure 65 "$sender" --check "$fixture_dir/invalid-status.json"

empty_home="$fixture_dir/empty-home"
mkdir -p "$empty_home"
expect_failure 78 env -u AGENTALERTS_AGENT_TOKEN HOME="$empty_home" \
  "$sender" --check-config "$example"

token_home="$fixture_dir/token-home"
mkdir -p "$token_home/.config/agent-alerts"
token_file="$token_home/.config/agent-alerts/token.env"
printf '%s\n' 'AGENTALERTS_AGENT_TOKEN=rk_agent_test_secret' >"$token_file"
chmod 600 "$token_file"
env -u AGENTALERTS_AGENT_TOKEN HOME="$token_home" \
  "$sender" --check-config "$example" >/dev/null

expect_failure 78 env AGENTALERTS_AGENT_TOKEN=rk_agent_test_secret \
  AGENTALERTS_WEBHOOK_URL=custom-destination \
  "$sender" --check-config "$example"

chmod 644 "$token_file"
expect_failure 78 env -u AGENTALERTS_AGENT_TOKEN HOME="$token_home" \
  "$sender" --check-config "$example"

printf '%s\n' "Agent Alerts webhook helper checks passed."
