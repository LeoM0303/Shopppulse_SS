# 7. Report snapshots in Blob Storage with a lifecycle policy

Date: 2026-09-21

## Status

Accepted

## Context

The dashboard summary only ever existed in two places: a Redis key with a
five-minute TTL, and whatever the database could recompute for the last 24
hours. Nothing kept a history, so "what did the dashboard say last Tuesday" had
no answer, and the platform had no example of object storage at all.

Keeping the history in PostgreSQL was the obvious alternative. It is the wrong
shape: the snapshots are immutable JSON documents that are written once and read
rarely, and storing them in the database grows the thing we pay to keep
highly available and back up.

## Decision

A dedicated storage account per environment, private-endpoint only, shared key
access disabled, holding one `reports` container. The worker writes a snapshot
after recomputing the summary, rate limited to one write per 15 minutes by
default, keyed by day: `2026-09-21/summary-160509.json`. The API exposes
`GET /api/reports` for listing them.

Writing is a side channel. A storage failure is logged and dropped, and never
costs us the Service Bus message that triggered the recompute.

A lifecycle management policy handles the rest, so nobody has to remember to
clean up:

| Environment | Cool | Archive | Delete |
|-------------|------|---------|--------|
| dev | 7 days | 30 days | 90 days |
| prod | 30 days | 90 days | 730 days |

Dev deliberately uses short steps so that the policy can be observed working
rather than taken on faith.

## Consequences

The archive costs close to nothing, tiers itself down, and the split between the
worker's Contributor role and the API's Reader role means the read path cannot
corrupt the history.

Two limitations are worth stating. Snapshots only appear while the worker is
running, and KEDA scales the worker to zero on an empty queue — so quiet periods
produce no snapshots, which is acceptable because there is nothing new to
record. And archived blobs need a rehydration step before they can be read, so
`GET /api/reports` lists them but downloading an archived snapshot is not an
online operation. A Kubernetes `CronJob` would be the fix for the first point if
guaranteed snapshots ever become a requirement.
