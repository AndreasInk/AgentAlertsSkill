---
name: agent-alerts-setup
description: Set up an automation that sends concise Agent Alerts updates to iPhone through the hosted HTTPS webhook and bundled send_webhook.sh helper. Use when configuring a report, monitor, schedule, CI job, Codex, Cursor, Claude, or another workflow that should publish Live Activity updates, widget refreshes, grouped notifications, or Control Widget state.
---

# Agent Alerts Setup

Design the automation, configure the hosted webhook, and hand runtime sends to
`$agent-alerts-execution`. Do not send during setup unless the user asks for a
smoke test.

## Start Here

Open or direct the user to:

```text
https://www.andreas.ink/agent
```

Follow the page's current connection flow with Agent Alerts on iPhone. It
creates a publish-only token for the runtime. Do not ask the user to paste that
token into chat.

## Configure The Webhook

1. Name the runtime and complete the connection flow at the public setup page.
2. Store the one-time token as `AGENTALERTS_AGENT_TOKEN` in the runtime's secret
   manager.
3. For a local automation, use the user-approved
   `~/.config/agent-alerts/token.env` file with mode `0600`. Store exactly one
   line: `AGENTALERTS_AGENT_TOKEN=<token>`. The user must enter it outside the
   AI conversation.
4. Use the endpoint built into
   `../agent-alerts-execution/scripts/send_webhook.sh`. Set
   `AGENTALERTS_WEBHOOK_URL` only when the setup page supplies a different
   HTTPS endpoint.
5. Allow outbound HTTPS only to that endpoint.
6. Authorize the exact absolute path to `send_webhook.sh` for unattended runs.
   Do not grant broad shell access.

Never put the token in a prompt, URL, query string, log, source file, tracked
settings file, shell history, or command argument.

## Prepare And Validate A Test

Copy `../agent-alerts-execution/assets/compact-webhook-payload.json` to a
writable payload file and replace its example values. Use a stable, unique
idempotency key for the event.

Validate the payload:

```bash
../agent-alerts-execution/scripts/send_webhook.sh --check payload.json
```

Validate the payload, token source, permissions, and endpoint without sending:

```bash
../agent-alerts-execution/scripts/send_webhook.sh --check-config payload.json
```

Then send one non-sensitive smoke test:

```bash
../agent-alerts-execution/scripts/send_webhook.sh payload.json
```

For an unattended automation, repeat `--check-config` and the smoke send from
the real saved runner. Both must complete without an approval prompt. If the
runner cannot execute the exact helper or reach the endpoint, stop with
`AGENTALERTS_SCRIPT_NOT_AUTHORIZED`.

## Design The Alert

Define:

1. Signal, data source, and trigger.
2. `good`, `warning`, and `critical` mappings.
3. Skip conditions, quiet hours, and exclusions.
4. A stable `activity_id` or notification identifier.
5. Surfaces: `live_activity`, `widget`, and/or `notification`.
6. Action text and a safe target URL or app deep link.
7. A durable scheduler when the alert runs later or repeatedly.

Agent Alerts delivers updates; it does not keep an agent session alive. A
future or recurring run is incomplete until the scheduler remains registered
after the current session closes. Otherwise return
`AGENTALERTS_SCHEDULER_NOT_DURABLE`.

## Payload Contract

Use the compact webhook body for ordinary alerts:

```json
{
  "title": "Build finished",
  "summary": "All tests passed.",
  "status": "good",
  "activity_id": "build-monitor",
  "source_name": "Codex",
  "surfaces": ["live_activity", "notification"],
  "idempotency_key": "build-monitor-2026-07-29T18-30-00Z"
}
```

The webhook requires:

```text
Authorization: Bearer <AGENTALERTS_AGENT_TOKEN>
Content-Type: application/json
Idempotency-Key: <same value as idempotency_key>
```

The helper supplies these headers without exposing the token in the process
arguments. Always use the helper; do not recreate the request manually.

Compact sends default to one upserted activity named `webhook`, production
delivery, and `live_activity` plus `notification` when those fields are
omitted. Set them explicitly when the automation needs a different result.

For widgets, Control Widget state, builder layouts, or other advanced fields,
use the webhook's full snake_case contract with a nested `payload` object. Do
not mix a full `payload` object with compact `title`, `summary`, `status`,
`source_name`, or `deep_link` fields.

## Copy And Delivery Rules

Keep visible copy complete and within these limits:

| Field | Maximum characters |
| --- | ---: |
| `source_name` | 14 |
| `title` | 32 |
| `summary` | 96 |

Do not rely on truncation or add ellipses.

- `live_activity` updates the Dynamic Island or Lock Screen.
- `widget` needs its widget identifier, a small non-secret snapshot, and
  reload enabled.
- `notification` needs a stable thread identifier for grouping.
- Control Widget state should be true for active warning or critical states
  and false for clear or resolved states.

## Runtime Handoff

Write one exact runtime instruction:

```text
Use $agent-alerts-execution. Evaluate the configured skip condition first.
If a send is needed, write the prepared Agent Alerts JSON to the approved
payload path, then invoke the authorized absolute send_webhook.sh path with
that file. Read the token only from AGENTALERTS_AGENT_TOKEN or the approved
token.env file. Report the returned status and target, success, and failure
counts without printing secrets.
```

Setup is complete only when the real runner validates configuration and sends
without interaction, the schedule is durable when required, and the result is
reported without overstating device-visible delivery.
