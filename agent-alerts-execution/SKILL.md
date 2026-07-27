---
name: agent-alerts-execution
description: Execute an Agent Alerts send from an existing automation. Use when an agent, CI job, scheduled task, Codex, Cursor, Claude, or other workflow has evaluated state and now needs to send or skip an iPhone Live Activity update, widget refresh, grouped push notification, or Control Widget update through the default HTTPS webhook, optional local macOS MCP, or an existing legacy CLI path.
---

# Agent Alerts Execution

Run this skill only after the automation has evaluated its current state. Do not
redesign the automation or create credentials here.

Use **Agent Alerts** in user-facing text and configuration:
`agentalerts_send`, `AGENTALERTS_WEBHOOK_URL`,
`AGENTALERTS_AGENT_TOKEN`, and `agentalerts`.

## Runtime Rules

1. Read the automation's configured route and current state.
2. If its skip condition is true, do not send.
3. Use the configured HTTPS webhook by default.
4. Use local `agentalerts_send` only when the automation explicitly selected
   the configured macOS MCP helper.
5. Use `agentalerts send --file payload.json` only when the automation explicitly
   selected the CLI path.
6. Keep deep links, idempotency, and payload data in JSON. Never print,
   interpolate, echo, or log `AGENTALERTS_AGENT_TOKEN`.
7. Do not install, authenticate, create tokens, or change endpoint configuration
   during runtime unless the automation explicitly permits setup.

## Local MCP Route

Call `agentalerts_send` with the configured JSON payload. The helper defaults
`apnsEnv` to `production`, generates deterministic idempotency when omitted, and
cannot read files, run shell commands, listen on localhost, or schedule jobs.

For a repeated report, use a stable `activityId` with
`updateMode: "upsert_single"`. Keep `idempotencyKey` stable only for retries of
the same event. Use `start_new` only when a separate Live Activity is intended.

```json
{
  "activityId": "release-watch",
  "updateMode": "upsert_single",
  "idempotencyKey": "release-watch-2026-07-25T18-00Z",
  "payload": {
    "generatedAt": 1785002400,
    "title": "Release verification",
    "summary": "Build passed; simulator smoke test is running.",
    "status": "warning",
    "template": "agent",
    "sourceName": "Codex",
    "primaryLabel": "Progress",
    "primaryValue": "68%",
    "footer": "Waiting on smoke test.",
    "action": "Open run",
    "deepLink": "https://example.com/run"
  },
  "surfaces": ["live_activity", "notification"],
  "notification": {
    "title": "Release verification",
    "body": "Build passed; smoke test is running.",
    "threadId": "release-watch"
  }
}
```

Use camelCase for local MCP and legacy CLI JSON. The legacy CLI command is:

```bash
agentalerts send --file payload.json
```

## HTTPS Webhook Route

POST to the endpoint configured during setup. Source the token from the runtime
secret manager into the Authorization header; never place it in the URL or send
an agent token in the URL or a legacy agent-token header.

For a normal alert, prefer the compact webhook body:

```json
{
  "title": "Build finished",
  "summary": "All tests passed.",
  "status": "good",
  "activity_id": "build-monitor",
  "source_name": "Claude",
  "surfaces": ["live_activity", "notification"],
  "idempotency_key": "build-monitor-2026-07-27T14-30-00Z"
}
```

For shell-based runtimes, copy
`assets/compact-webhook-payload.json`, replace its example values and fresh
idempotency key, then use the bundled helper:

```bash
scripts/send_webhook.sh --check payload.json
scripts/send_webhook.sh payload.json
```

The helper reads the payload and uses `AGENTALERTS_AGENT_TOKEN` from the
environment when present. Otherwise it safely parses the designated
`~/.config/agent-alerts/token.env` file after requiring mode `0600`; it never
shell-sources that file. It defaults to the hosted Agent Alerts
`agentalerts-webhook` endpoint; set `AGENTALERTS_WEBHOOK_URL` only when the app
or public setup page supplied a different endpoint. It validates compact/full
mode separation, keeps the Bearer token out of argv, and retries one transient
failure with the unchanged payload and idempotency key.

Use `--check-config` during setup to validate the JSON, token environment/file,
permissions, and endpoint without making a network request.

At runtime, do not request a new broad shell permission or switch to raw curl
when the helper is blocked. Return `AGENTALERTS_SCRIPT_NOT_AUTHORIZED` when the
exact helper command, skill path, payload path, secret injection, or webhook
network egress was not preauthorized during setup.

Send these headers:

```text
Authorization: Bearer <AGENTALERTS_AGENT_TOKEN from secret manager>
Content-Type: application/json
Idempotency-Key: <stable key for this event>
```

The compact route defaults to `event: "update"`, `update_mode:
"upsert_single"`, production APNs, and `live_activity` plus `notification`.
It accepts `good`, `warning`, or `critical`; `title` is at most 32 characters;
`summary` is at most 96; and `source_name` is at most 14. Set
`surfaces: ["notification"]` or another allowed selection only when the
automation intentionally changes the default surfaces.

For widgets, Control Widget state, custom builder layouts, or any other
advanced field, use the full webhook contract selected at setup. It must use the
endpoint's snake_case fields and a `payload` object. Do not mix full `payload`
with compact `title`, `summary`, `status`, `source_name`, or `deep_link` fields.

## Surface And Copy Rules

- `live_activity`: Dynamic Island or Lock Screen update.
- `widget`: needs `widget.widgetId`, a small non-secret `widget.snapshot`, and
  `reload: true`.
- `notification`: needs `notification.threadId` to group related alerts.
- `notification.control.isOn`: true for active warning or critical states;
  false for clear or resolved states.

Keep visible copy complete and under these limits: `sourceName` 14, `title` 32,
`summary` 96, labels 14, primary value and delta 12, secondary value 14,
`footer` 42, `chartTitle` 20, and `action` 20 characters. Do not rely on
truncation or use ellipses.

For `template: "agent"`, use progress fields only when known. For
`template: "builder"`, use the constrained builder DSL; do not send arbitrary
SwiftUI, scripts, HTML, remote images, or runtime widget network fetches.

## Skip And Error Discipline

Skip without sending when the state is normal under a change-only policy, source
data is untrustworthy, quiet hours apply, an idempotent event already sent, or
the payload lacks required fields.

Report the actual delivery outcome:

- missing local tool: the local MCP helper is unavailable; use the webhook only
  if that route was configured
- missing endpoint or token: the cloud route lacks its configured prerequisite
- `AGENTALERTS_SCRIPT_NOT_AUTHORIZED`: the unattended runner cannot execute the
  exact helper or reach its configured webhook without interaction
- HTTP 401: token is missing, revoked, expired, malformed, or sent incorrectly
- HTTP 400: correct the JSON, conflicting idempotency keys, or forbidden URL
  credential
- HTTP 402 or `live_activity_daily_limit_reached`: report the quota/paywall
  state
- no registered targets: the iPhone has not signed in or synced tokens
- `sent_pending_device_ack`: APNs accepted the send, but the iPhone has not
  confirmed a visible Live Activity; do not claim user-visible success
- partial delivery: report target, success, and failure counts instead of
  treating `ok: true` as complete delivery

At runtime, answer briefly: skipped with reason, sent with route and verified
delivery fields, or failed with the actionable prerequisite. Never include a
secret.
