# Agent Alerts Agent Skills

[![skills.sh](https://skills.sh/b/AndreasInk/AgentAlertsSkill)](https://skills.sh/AndreasInk/AgentAlertsSkill)

Trusted, reviewable agent skills for sending Agent Alerts to iPhone through one
hosted HTTPS webhook and one bundled script.

Start new setups at [andreas.ink/agent](https://www.andreas.ink/agent). The
connection flow creates a publish-only token for the runtime. For a hosted
runtime, store it in that runtime's secret manager as
`AGENTALERTS_AGENT_TOKEN`. For a local Mac setup, store exactly
`AGENTALERTS_AGENT_TOKEN=<token>` in
`~/.config/agent-alerts/token.env`, set the file to mode `0600`, and enter the
token outside the agent conversation. Never paste the token into agent chat.

This repository publishes two skills:

- `$agent-alerts-setup` designs and verifies an automation.
- `$agent-alerts-execution` sends or skips an alert through
  `agent-alerts-execution/scripts/send_webhook.sh`.

The script validates the payload and secret configuration, uses the hosted
endpoint by default, keeps the token out of process arguments, and preserves
idempotency across a retry.

## Install

```bash
npx skills add AndreasInk/AgentAlertsSkill
```

Or ask your agent:

```text
Install https://github.com/AndreasInk/AgentAlertsSkill.
Use $agent-alerts-setup to configure my automation.
Use $agent-alerts-execution when it is time to send or skip.
```

These files follow Vercel's
[Agent Skills guidance](https://vercel.com/docs/agent-resources/skills): focused
instructions, clear activation descriptions, and a deterministic bundled
script. The public [skills.sh directory](https://skills.sh) surfaces
GitHub-hosted skills from install activity and publishes security-audit
information. Review skill files and scripts before installing or updating
them.

## Trust Model

- One publish-only token per runtime.
- One auditable HTTPS helper for every send.
- No token in prompts, URLs, logs, source files, or command arguments.
- Exact-script authorization for unattended runners.
- Stable idempotency keys for retries.
- Delivery counts reported without treating request acceptance as
  device-visible proof.

## Live Activity Examples

| Ops Calm | Release Readiness | Conversion Trend |
| --- | --- | --- |
| ![Ops Calm](assets/live-activity-previews/live-activity-ops-calm.png) | ![Release Readiness](assets/live-activity-previews/live-activity-release-readiness.png) | ![Conversion Trend](assets/live-activity-previews/live-activity-mixpanel-funnel.png) |

| Storefront Trend | Service Errors | Traffic Incident |
| --- | --- | --- |
| ![Storefront Trend](assets/live-activity-previews/live-activity-app-store-analytics.png) | ![Service Errors](assets/live-activity-previews/live-activity-supabase-errors.png) | ![Traffic Incident](assets/live-activity-previews/live-activity-gcloud-incident.png) |

| Build Progress | Launch Console | Compact Console |
| --- | --- | --- |
| ![Build Progress](assets/live-activity-previews/live-activity-codex-agent-progress.png) | ![Launch Console](assets/live-activity-previews/live-activity-builder-launch-console.png) | ![Compact Console](assets/live-activity-previews/live-activity-builder-compact-console.png) |

## More Info

Read the [Agent Alerts docs](https://andreas.craft.me/qtX8oWJYSSxbJ2) or join
the [iOS TestFlight](https://testflight.apple.com/join/KCr6Sxgn).
