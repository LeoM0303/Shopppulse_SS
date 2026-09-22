# 9. Schema changes go through Alembic, not through the application

Date: 2026-09-22

## Status

Accepted

## Context

The API created its schema on startup:

```python
@app.on_event("startup")
async def on_startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
```

That is fine for a demo and wrong for everything else. `create_all` only ever
creates missing tables — it never alters an existing one, so any change to a
column silently did nothing and the running schema quietly diverged from the
model. Two API replicas starting at once both issue DDL. And a schema change
was invisible in review, because the diff showed a Python attribute rather than
a statement that would run against production.

## Decision

Alembic owns the schema. Revision `0001` is the baseline: the table as
`create_all` used to build it, plus two indexes the dashboard queries have
always wanted (`occurred_at`, and `product_id` with `occurred_at`).

Migrations run as a Kubernetes `Job` named `db-migrate-<image tag>`, applied and
waited on *before* the rollout, in both `deploy.yml` and `scripts/deploy.ps1`.
The tag in the name makes the job immutable per release and makes "which
migration ran for which version" a `kubectl get jobs` away. If the job fails,
the pipeline stops before any new pod starts.

Locally, docker-compose runs `alembic upgrade head` in the API entrypoint. One
replica, no race, and a developer never has to remember a separate command.

An environment whose table came from the `create_all` era is adopted with
`alembic stamp 0001` rather than by running the baseline.

## Consequences

Schema changes are reviewable, repeatable and ordered, and a failed migration
stops the deployment instead of producing pods that crash against a table that
is not there.

The cost is a real one: a migration that has already run cannot be undone by
rolling back the image. Rollback of a release with a schema change means either
a `downgrade` revision or a point-in-time restore, which is why the incident
runbook covers both. The practical discipline that follows is to keep
migrations backwards compatible with the previous image — add columns before
using them, drop them one release later.
