# 2. One Terraform root with feature flags instead of two stacks

Date: 2026-09-21

## Status

Accepted

## Context

The project originally had two Terraform directories: `terraform` for the AKS
stack and `terraform-data` for the data services. Redis, PostgreSQL and Key
Vault appeared in both, with slightly different arguments, because each stack
needed them for its own reason. Reviewers immediately spotted the duplication:
the same service described twice means two places to fix any bug, and no single
answer to "what does this environment actually contain".

The reason for the split was that the data layer had to be deployable on its own,
without paying for an AKS cluster.

## Decision

One root module in `infra/terraform`, with shared modules under `modules/` and
one root file per service. The ability to deploy a subset is expressed with
feature flags instead of separate directories:

- `create_network` — create the resource group, VNet and subnets, or attach to existing ones
- `enable_aks` — the cluster, workload identities and service accounts
- `enable_servicebus` — messaging
- `enable_monitoring` — workspace, Container Insights, Application Insights, alerts
- `enable_storage` — blob account for report snapshots

Environments differ only by a variables file and a state key, not by code.

## Consequences

A service is defined once, so drift between environments comes from inputs
rather than from code that fell behind. `terraform plan` describes the whole
environment in one run, which is what makes the plan comment on a pull request
meaningful.

The cost is that `count` appears on several modules, and every reference to an
optional module needs `try(...)` or an index. That is noisier than a plain
reference, and it is the price of keeping one source of truth.
