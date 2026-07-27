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

jq 'del(.idempotency_key)' "$example" >"$fixture_dir/missing-idempotency.json"
expect_failure 65 "$sender" --check "$fixture_dir/missing-idempotency.json"

jq '. + {"payload": {"title": "Mixed"}}' "$example" >"$fixture_dir/mixed-mode.json"
expect_failure 65 "$sender" --check "$fixture_dir/mixed-mode.json"

jq '.status = "unknown"' "$example" >"$fixture_dir/invalid-status.json"
expect_failure 65 "$sender" --check "$fixture_dir/invalid-status.json"

expect_failure 78 env -u AGENTALERTS_AGENT_TOKEN "$sender" "$example"

printf '%s\n' "Agent Alerts webhook helper checks passed."
