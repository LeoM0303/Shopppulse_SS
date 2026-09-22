# 6. One Log Analytics workspace for platform, container and application telemetry

Date: 2026-09-21

## Status

Accepted

## Context

Until now the only way to see what the system was doing was `kubectl logs` and
the Azure portal's per-resource metric blades. Logs disappeared with the pod, so
a crash loop that fixed itself left nothing behind, and there was no alert on
anything — a full PostgreSQL disk would have been discovered by a user.

The alternative to Azure Monitor is a Prometheus, Loki and Grafana stack in the
cluster. It is more portable and, for a cluster this size, more work to run than
the thing it monitors: the storage, retention and upgrade of the monitoring stack
becomes another service to operate, and it goes down exactly when the cluster
does.

## Decision

One `azurerm_log_analytics_workspace` per environment, with three feeds into it:

1. **Platform logs and metrics** — a diagnostic setting on every managed resource
   (AKS, PostgreSQL, Key Vault, ACR, Service Bus, Redis, the blob service) sends
   `allLogs` and `AllMetrics`. Redis Enterprise is metrics-only, it has no log
   categories.
2. **Container logs and cluster inventory** — the Container Insights addon, with
   managed identity authentication so there is no workspace key to store.
3. **Application telemetry** — Application Insights in the same workspace, fed by
   `azure-monitor-opentelemetry` in the API and the worker. Instrumentation is
   opt-in at runtime: with no connection string in the environment the app runs
   uninstrumented, which is what docker-compose and the test suite need.

Alerts fan out through a single action group, so adding a receiver is one change:

| Alert | Condition |
|-------|-----------|
| Node CPU | above 80% for 15 minutes |
| Node memory | working set above 85% for 15 minutes |
| PostgreSQL CPU | above 80% for 15 minutes |
| PostgreSQL storage | above 85%, severity 1 — the disk cannot be shrunk back |
| Pod restarts | a pod restarting more than 3 times in 30 minutes |
| Container errors | more than 20 ERROR lines in 15 minutes |

Ingestion is capped at 1 GB/day in dev. On a student subscription an accidental
log storm is a billing incident, and the cap turns it into missing data instead.
Production removes the cap and samples application telemetry at 30% instead,
because going blind during an incident costs more than the ingestion.

## Consequences

An incident can be investigated after the fact, from the alert down to the
request that caused it, in one query language. The runbook in
`docs/runbooks/incident-response.md` can reference concrete tables.

This ties the observability story to Azure. Moving clouds would mean rewriting
the queries and the alerts, though not the application code, since the SDK is
OpenTelemetry underneath.

Two smaller consequences worth remembering: the daily cap silently drops data
once it is hit, and `log_retention_days = 30` is the point where Log Analytics
stops being free.
