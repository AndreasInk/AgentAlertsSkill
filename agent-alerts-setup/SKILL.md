---
name: agent-alerts-setup
description: Set up a user-facing automation that sends Agent Alerts iPhone Live Activity updates, Home or Lock Screen widget refreshes, grouped push notifications, or Control Widget state updates. Use when configuring a report, monitor, schedule, CI job, Codex, Cursor, Claude, or other workflow that should publish concise Agent Alerts status updates through the default HTTPS webhook or optional local macOS MCP.
---

# Agent Alerts Setup

Design the automation and hand it to `$agent-alerts-execution` for runtime.
Do not send during setup unless the user explicitly asks for a smoke test.

## Start At The Public Setup Page

For a new setup, open or direct the user to:

```text
https://www.andreas.ink/agent
```

Treat the page's agent instructions and generated setup details as the current
hosted contract. If the user pastes `/agent`, `/agent/`, `/agent-alerts`, or an
Agent Alerts setup link, follow its advertised agent-instructions URL instead
of answering only from the local skill.

The public page connects the web flow with Agent Alerts on iPhone and guides
the user through creating a publish-only token. Do not reduce setup to “open
the iPhone app and paste a token here.”

## Name And Compatibility Policy

Use **Agent Alerts** in user-facing copy and configuration. Use these
identifiers consistently:

- local tools: `agentalerts_status`, `agentalerts_send`, and `agentalerts_alarm`
- cloud configuration: `AGENTALERTS_WEBHOOK_URL` and
  `AGENTALERTS_AGENT_TOKEN`
- optional CLI: `agentalerts`

Do not rename those identifiers in MCP configuration, headers, payloads, secret
names, or scripts.

## Choose One Delivery Route

Choose the route before designing the runtime prompt:

1. **HTTPS webhook** — use by default for local or hosted Codex, Claude,
   Cursor, CI, no-code tools, and other runtimes with outbound HTTPS.
2. **Local macOS MCP** — use only when the user explicitly asks for a
   desktop-local integration that can start the Agent Alerts Mac helper.
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

1. Start at `https://www.andreas.ink/agent` and follow the page's connection
   flow with Agent Alerts on iPhone.
2. Create a named publish token for the specific runtime when the page/app
   prompts for it.
3. Have the user place the displayed token directly into the runtime's secret
   or environment configuration as `AGENTALERTS_AGENT_TOKEN`. Never ask the
   user to paste the token into AI chat. For a local Claude Code or Codex
   workflow, use `~/.config/agent-alerts/token.env` as the designated durable
   location when the user agrees. Create it with mode `0600`, keep it outside
   source control, and have the user enter the token outside the AI
   conversation. Store exactly `AGENTALERTS_AGENT_TOKEN=<token>` and load it
   into the automation environment without printing the file.
4. The bundled helper defaults to the hosted Agent Alerts endpoint. Set
   `AGENTALERTS_WEBHOOK_URL` only when the app or public setup page supplies a
   different endpoint.
5. Allow only outbound HTTPS to the supplied endpoint. Do not put the token in a
   URL, query string, prompt, source file, log, or shell history.
6. Run one compact idempotent smoke test and verify the returned delivery status.

Use the hosted endpoint advertised by the public setup page or the exact
different HTTPS endpoint supplied by Agent Alerts. Do not derive a function
path or replace a hosted function name.

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
  "title": "Build finished",
  "summary": "All tests passed.",
  "status": "good",
  "activity_id": "build-monitor",
  "source_name": "Claude",
  "surfaces": ["live_activity", "notification"],
  "idempotency_key": "build-monitor-2026-07-27T14-30-00Z"
}
```

Copy `../agent-alerts-execution/assets/compact-webhook-payload.json`, replace the
example values and idempotency key, then validate it without sending:

```bash
../agent-alerts-execution/scripts/send_webhook.sh --check payload.json
```

## Authorize Unattended Automations

Before scheduling a Codex or Claude Code automation:

1. Resolve the installed absolute path to
   `agent-alerts-execution/scripts/send_webhook.sh`.
2. Allow that exact executable path with arguments. Do not broadly allow
   `Bash`, `sh`, `/usr/bin/curl`, or unrestricted shell execution.
3. Make the skill folder readable/executable and the automation payload
   location writable inside the runner sandbox.
4. Inject `AGENTALERTS_AGENT_TOKEN` through the runner's secret/environment
   configuration. Inject `AGENTALERTS_WEBHOOK_URL` only when the setup flow
   supplied a different endpoint. Never store the token in a tracked settings
   file. A local runner may load the designated `token.env` file through its
   preauthorized launcher without printing its contents.
5. Allow outbound HTTPS only to the configured webhook host.
6. Run one interactive smoke test through the exact automation command before
   enabling its schedule. Confirm the response fields without claiming visible
   device delivery.

For Codex, approve a reusable command prefix scoped to the exact absolute helper
path. Do not rely on an approval prompt during an unattended run.

For Claude Code, add a narrow permission rule through `/permissions`,
`.claude/settings.json`, or `--allowedTools`:

```text
Bash(/absolute/path/to/agent-alerts-execution/scripts/send_webhook.sh:*)
```

Do not use `Bash` without a specifier or
`--dangerously-skip-permissions`. Environment-level network and filesystem
policies still need to permit the helper.

If the scheduled runner cannot execute the helper without interaction, stop
setup and report `AGENTALERTS_SCRIPT_NOT_AUTHORIZED`.

Compact webhook sends default to one upserted activity named `webhook` when
`activity_id` is omitted, production APNs, and both `live_activity` plus
`notification` surfaces. Set `surfaces` explicitly when the automation should
limit that default. Use the full send contract only when the workflow needs
widgets, Control Widget state, builder layouts, or other advanced fields.

## Credential Rules

- Prefer the webhook unless the user explicitly selected local macOS MCP.
- Create one revocable token per runtime; rotate or revoke any token that appears
  in a log, prompt, commit, or shared transcript.
- Do not copy local CLI sessions into a cloud runtime.
- Do not ask the user to paste a token into chat.
- The designated local token file is
  `~/.config/agent-alerts/token.env`. It must be user-approved, outside source
  control, mode `0600`, and loaded without echoing or logging its contents.
- Do not print, echo, or inline `AGENTALERTS_AGENT_TOKEN`.
- Do not put passwords, Supabase keys, APNs credentials, or token plaintext in
  commands or automation instructions.

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
