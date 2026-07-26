---
name: agent-alerts-setup
description: Set up a user-facing automation that sends Agent Alerts iPhone Live Activity updates, Home or Lock Screen widget refreshes, grouped push notifications, or Control Widget state updates. Use when configuring a report, monitor, schedule, CI job, Codex, Cursor, Claude, or other workflow that should publish concise Agent Alerts status updates through local macOS MCP or an HTTPS webhook.
---

# Agent Alerts Setup

Design the automation and hand it to `$agent-alerts-execution` for runtime.
Do not send during setup unless the user explicitly asks for a smoke test.

## Name And Compatibility Policy

Use **Agent Alerts** in user-facing copy and configuration. Use these
identifiers consistently:

- local tools: `agentalerts_status`, `agentalerts_send`, and `agentalerts_alarm`
- cloud token and endpoint conventions: `AGENTALERTS_AGENT_TOKEN` and
  `/functions/v1/agentalerts-webhook`
- optional CLI: `agentalerts`

Do not rename those identifiers in MCP configuration, headers, payloads, secret
names, or scripts.

## Choose One Delivery Route

Choose the route before designing the runtime prompt:

1. **Local macOS MCP** — use for a local AI desktop client that can start the
   Agent Alerts Mac helper. This is the preferred local route.
2. **HTTPS webhook** — use for hosted agents, CI, no-code tools, or any runtime
   with outbound HTTPS but no access to the paired Mac. This is the preferred
   cloud route.
3. **Legacy CLI** — use only when an existing automation already depends on
   `agentalerts send --file`; do not select it for a new cloud integration when
   the webhook is available.

Agent Alerts is not a scheduler. Keep schedules in Codex, Claude, Cursor, CI,
cron, launchd, or the user's workflow runner.

## Local macOS MCP Setup

1. Sign into Agent Alerts on iPhone and allow notifications.
2. Open Agent Alerts for Mac and approve the discovered Mac from iPhone.
3. Choose the target AI app in the Mac app and copy its generated setup command
   or configuration.
4. Restart the AI client, call `agentalerts_status`, and send one visible test
   alert before creating the automation.

Use the app-generated MCP command or configuration. Register the server as
`agentalerts`; do not guess a helper path when the app provides one.

The helper is stdio-only. It cannot read files, run shell commands, listen on a
network port, schedule work, or read the Mac app's normal Supabase session.

## HTTPS Webhook Setup

1. Sign into Agent Alerts on iPhone, allow notifications, and let it finish
   syncing device and Live Activity tokens.
2. In **Settings → Webhooks & Agents**, create a named publish token for the
   specific runtime. Copy or share the generated endpoint and setup details.
3. Store the endpoint as a non-secret configuration value and the displayed
   token value as `AGENTALERTS_AGENT_TOKEN` in that runtime's secret
   manager. The plaintext token is shown once.
4. Allow only outbound HTTPS to the supplied endpoint. Do not put the token in a
   URL, query string, prompt, source file, log, or shell history.
5. Run one compact idempotent smoke test and verify the returned delivery status.

The endpoint is normally:

```text
https://<project-ref>.supabase.co/functions/v1/agentalerts-webhook
```

The webhook accepts `POST` JSON only. It requires:

```text
Authorization: Bearer <AGENTALERTS_AGENT_TOKEN secret>
Content-Type: application/json
Idempotency-Key: <stable-run-key>
```

Send the token only in the Authorization header. Never use token query
parameters or a legacy agent-token header for this webhook.

Use this compact body for ordinary cloud alerts:

```json
{
  "title": "Release verification",
  "summary": "Build passed; simulator smoke test is running.",
  "status": "warning",
  "activity_id": "release-watch",
  "source_name": "CI"
}
```

Compact webhook sends default to one upserted activity named `webhook` when
`activity_id` is omitted, production APNs, and both `live_activity` plus
`notification` surfaces. Set `surfaces` explicitly when the automation should
limit that default. Use the full send contract only when the workflow needs
widgets, Control Widget state, builder layouts, or other advanced fields.

## Credential Rules

- Prefer the macOS helper for local AI apps and the webhook for cloud runtimes.
- Create one revocable token per runtime; rotate or revoke any token that appears
  in a log, prompt, commit, or shared transcript.
- Do not copy local CLI sessions into a cloud runtime.
- Do not print, echo, or inline `AGENTALERTS_AGENT_TOKEN`.
- Do not put passwords, Supabase keys, APNs credentials, or token plaintext in
  commands or automation instructions.
- Use `$agent-alerts-webhook-self-host` only when the user explicitly requests a
  dedicated Supabase deployment; it is not needed for the hosted endpoint.

## Design The Alert Contract

Establish these decisions before writing runtime instructions:

1. Signal, data source, and trigger.
2. `good`, `warning`, and `critical` mappings.
3. Explicit skip conditions, quiet hours, and exclusions.
4. Delivery route and the stable activity or notification identifier.
5. Surfaces: `live_activity`, `widget`, `notification`, and optional Control
   Widget state.
6. Live Activity update mode: `start_new`, `update_existing`, `upsert_single`,
   or `coalesce`.
7. Action text and target URL or app deep link.

Choose an explicit template for local MCP or full-contract sends:

- `ops`: backend health, logs, failures, migrations, queues, uptime.
- `growth`: revenue, trials, conversion, App Store status, product metrics.
- `agent`: Codex, Cursor, Claude, CI, or background-agent progress.
- `builder`: constrained JSON-to-SwiftUI Live Activity layouts.

Use `upsert_single` with a stable `activityId` for one persistent report;
`start_new` for separate runs; `update_existing` when missing state must not be
restarted; and `coalesce` with stable `activityId` plus `coalesceKey` for several
independent checks. Idempotency identifies one retried event; it does not select
the update policy.

## Display And Surface Rules

Keep visible copy complete and within these limits:

| Field | Maximum characters |
| --- | ---: |
| `sourceName` | 14 |
| `title` | 32 |
| `summary` | 96 |
| `primaryLabel` | 14 |
| `primaryValue` | 12 |
| `primaryDelta` | 12 |
| `secondaryLabel` | 14 |
| `secondaryValue` | 14 |
| `footer` | 42 |
| `chartTitle` | 20 |
| `action` | 20 |

Put a label in `*Label`, a value in `*Value`, and a signed change in
`primaryDelta`. Do not rely on renderer truncation or add ellipses.

- `live_activity` updates the Dynamic Island or Lock Screen.
- `widget` needs `widget.widgetId`, a small non-secret `widget.snapshot`, and
  `reload: true`.
- `notification` needs `notification.threadId` for grouping.
- Set `notification.control.isOn` true for active warning or critical states and
  false for clear or resolved states.

Use `chatgpt://codex/threads/<thread-id>` to open a known current Codex thread
from iPhone. Use `codex://threads/new?...` only for desktop workspace handoff.

## Handoff To Runtime

Write one exact runtime instruction. It must tell the automation to evaluate
skip conditions first, select only its configured delivery route, keep secret
values out of output, and report delivery truth rather than only request
acceptance.

For local MCP:

```text
Use $agent-alerts-execution. If the skip condition is true, do not send.
Otherwise call agentalerts_send with the prepared Agent Alerts JSON payload.
Use activityId "release-watch", updateMode "upsert_single", and a stable
idempotencyKey for this run.
```

For a hosted webhook:

```text
Use $agent-alerts-execution. If the skip condition is true, do not send.
Otherwise POST the compact Agent Alerts JSON body to the configured webhook URL.
Source the Bearer token only from the runtime secret named AGENTALERTS_AGENT_TOKEN
and send a stable Idempotency-Key for this run. Do not print either secret.
```

For advanced payloads, use camelCase with `agentalerts_send` and the CLI;
use the webhook's documented snake_case HTTP contract instead. Do not mix a
webhook compact `title` or `summary` with a full `payload` object.
