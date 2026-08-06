---
name: agent-alerts-execution
description: Send or skip an Agent Alerts update through the hosted HTTPS webhook using the bundled send_webhook.sh helper. Use after an agent, CI job, scheduled task, Codex, Cursor, Claude, or another workflow has evaluated state and needs to publish an iPhone Live Activity update, choose a chart, progress, or direct Yes/No Live Activity presentation, refresh a widget, send a grouped notification, or update a Control Widget.
---

# Agent Alerts Execution

Run this skill only after the automation has evaluated its current state. Do
not redesign the automation, create credentials, or change endpoint
configuration during a normal run.

## Execute

1. Evaluate the configured skip condition. If it is true, do not send.
2. Write the prepared JSON to the automation's approved payload path.
3. For a setup or readiness check, run:

   ```bash
   scripts/send_webhook.sh --check-config payload.json
   ```

4. To send, run:

   ```bash
   scripts/send_webhook.sh payload.json
   ```

Use the installed skill's resolved absolute script path in unattended runners.
Do not switch to a manually recreated request when the helper is blocked.
Return `AGENTALERTS_SCRIPT_NOT_AUTHORIZED` if the exact script, payload path,
secret source, or HTTPS egress was not authorized during setup.

Place the payload and any automation-owned receipts inside the scheduler's
approved writable workspace. Configure that workspace before enabling the
schedule. A permitted webhook helper does not automatically authorize payload
creation.

Test payload creation from the real scheduled context, not only an interactive
session. Confirm the runner can create, replace, parse, and read back the exact
payload file without an approval prompt.

## Payload

For ordinary alerts, begin with
`assets/compact-webhook-payload.json`:

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

Keep the idempotency key unchanged only when retrying the same event. Use a new
key for a new event.

The helper:

- validates compact and full payload modes;
- reads `AGENTALERTS_AGENT_TOKEN` from the environment or safely parses the
  approved mode-`0600` `~/.config/agent-alerts/token.env` file;
- defaults to the hosted Agent Alerts endpoint at
  `bsakakesupfudupbxflj.supabase.co`;
- keeps the Bearer token out of process arguments;
- sends the JSON with a matching `Idempotency-Key`; and
- retries one transient failure with the unchanged payload.

Review the bundled
[`send_webhook.sh`](https://github.com/AndreasInk/AgentAlertsSkill/blob/main/agent-alerts-execution/scripts/send_webhook.sh)
helper to verify the destination, credential handling, payload validation, and
request behavior before authorizing it.

Set `AGENTALERTS_WEBHOOK_URL` only when the Agent Alerts setup page supplied a
different HTTPS endpoint. Never place credentials in the URL.

For widgets, Control Widget state, builder layouts, or other advanced fields,
use the configured full webhook contract with snake_case routing fields and a
nested `payload` object. Do not mix that object with compact `title`, `summary`,
`status`, `source_name`, or `deep_link` fields.

## Choose a Live Activity presentation

Keep the default presentation unless the underlying information benefits from
a more specific representation. Never invent chart points, progress, steps, or
a decision merely to make an alert look richer.

Choose one primary fixed-template visual family. Use `template: growth` for a
chart or `template: agent` for progress. Do not include both and claim both are
visible: put secondary information in metric text, use a validated custom
builder layout, or publish a separate activity.

- Use `chart_style: line` for continuous movement or direction over time.
- Use `chart_style: area` when the magnitude beneath a trend matters.
- Use `chart_style: bar` for discrete periods or categories.
- Use `progress_style: linear` for general continuous completion.
- Use `progress_style: ring` for one compact completion percentage.
- Use `progress_style: segmented` for a finite checklist or step sequence.
- Use `interaction.kind: yes_no` only for an explicit binary decision. A
  pending response is unknown, not No; iOS may require authentication before a
  Lock Screen control runs. Treat the decision card as the primary presentation
  while the interaction is active.

Omit `chart_style` and `progress_style` to retain the backward-compatible line
and linear defaults. Before selecting or composing a non-default presentation,
read `references/live-activity-variants.md`. When visual hierarchy matters,
inspect only the relevant bundled PNG with the available image-viewing tool.

## Schedule a future Live Activity

Use the server-backed schedule surface only for an explicit one-shot Live
Activity start from 1 minute through 30 days in the future. Supply exactly one
of `fireAt` or `fireInSeconds`, force new-activity routing, and retain the
returned schedule ID. Use that ID to check status or cancel while the request
is still queued. Recurring schedules remain the calling workflow's
responsibility.

With the Agent Alerts CLI, create the schedule with `agentalerts schedule
--file request.json`, then use `agentalerts schedule status SCHEDULE_ID` or
`agentalerts schedule cancel SCHEDULE_ID`. When the ReportKit remote MCP is
available, use its matching schedule, status, and cancel tools instead.

Report lifecycle truth precisely: `queued` is only server acceptance, `sent`
is only APNs acceptance, cancellation may become too late after dispatch is
claimed, and none of those states proves that the Live Activity appeared on
the iPhone.

## Safety

- Never print, interpolate, echo, log, or pass
  `AGENTALERTS_AGENT_TOKEN` as an argument.
- Never read the token file into chat or agent output.
- Never install, authenticate, rotate tokens, or widen permissions during a
  routine send.
- Skip when source data is untrustworthy, quiet hours apply, the event already
  sent, or required fields are missing.
- Keep `title` at most 32 characters, `summary` at most 96, and `source_name`
  at most 14. Use complete phrases without ellipses.

## Report Delivery Truth

Report the actual response:

- HTTP 401: token missing, revoked, expired, malformed, or sent incorrectly.
- HTTP 400: invalid JSON, conflicting idempotency keys, or forbidden URL
  credential.
- HTTP 402 or `live_activity_daily_limit_reached`: quota or paywall blocked the
  send.
- `no_targets`: the iPhone has not registered or synced the selected surface.
- `sent_pending_device_ack`: the service accepted the send, but the iPhone has
  not confirmed a visible Live Activity.
- partial delivery: report target, success, and failure counts.

At runtime, answer briefly: skipped with reason, sent through the webhook with
the returned delivery fields, or failed with the actionable prerequisite.
Never include a secret or claim device-visible success from request acceptance
alone.
