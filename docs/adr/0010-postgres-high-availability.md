# 10. Zone-redundant PostgreSQL in production, point-in-time restore everywhere

Date: 2026-09-22

## Status

Accepted

## Context

PostgreSQL was a single flexible server pinned to zone 1, with seven days of
backups. Losing that zone meant losing the database until someone restored it
by hand, and the only documented recovery was a restore that takes minutes to
tens of minutes depending on the size of the data.

The database is the one stateful thing in the stack. Redis is a cache that
refills itself, Service Bus is managed and zone redundant already, and the
cluster's own state can be recreated from Terraform and the registry.

## Decision

Availability is expressed per environment instead of being hard-coded:

| | dev | prod |
|---|---|---|
| SKU | `B_Standard_B1ms` (Burstable) | `GP_Standard_D2s_v3` (General Purpose) |
| High availability | off | `ZoneRedundant`, standby in zone 2 |
| Backup retention | 7 days | 35 days |
| Geo-redundant backup | off | on |

Dev runs without HA on purpose, not by omission: Burstable SKUs cannot do it at
all, and the cost of General Purpose plus a standby is not justified for an
environment that can be rebuilt from Terraform. Dev's recovery story is
point-in-time restore, and the runbook treats that as the normal path.

Two Azure constraints shape this. Geo-redundant backup can only be chosen when
the server is created, so switching it on later means a new server and a
migration. And zone-redundant HA doubles the compute bill, because the standby
is a full replica that serves no reads.

## Consequences

A zone failure in production becomes an automatic failover measured in tens of
seconds, with the application reconnecting through the same hostname. A region
failure becomes a geo-restore instead of data loss.

Failover is not free of visible effects: in-flight connections are dropped, so
the API and the worker will log connection errors and reconnect — both already
use `pool_pre_ping` and a retry loop respectively. Planned failover is also the
only way to test this, and the runbook says to do it deliberately rather than
to discover the behaviour during an incident.
