# 5. Terraform state in Azure Storage, one key per environment

Date: 2026-09-21

## Status

Accepted

## Context

State started out as a local file. That works for exactly one operator on one
machine: there is no locking, the file is easy to lose, and CI cannot plan at all
because it has no idea what exists. A plan comment on a pull request is only
useful if the plan runs against the same state the next apply will use.

## Decision

An `azurerm` backend in a dedicated storage account, created by
`scripts/bootstrap-state.ps1` outside the main stack so that destroying the
environment cannot destroy its own state. The account has versioning and a
30-day soft delete window, shared key access disabled, and `use_azuread_auth`
so both a human and the GitHub OIDC principal authenticate as themselves.

The backend is partial: `backend.tf` declares the backend, and the coordinates
arrive from `backend.hcl` locally and from `-backend-config` flags in CI.
Environments are separated by the state key — `shoppulse/dev.tfstate`,
`shoppulse/prod.tfstate` — with the same code and different variables files.

## Consequences

Two people can no longer corrupt the state, because blob leases give Terraform
real locking. CI can plan, which is what makes review of infrastructure changes
possible, and the nightly drift check works for the same reason.

The bootstrap is a chicken-and-egg step that is not in Terraform, so it is a
documented script instead. Switching environments means re-running `init` with a
different key, and forgetting to do so is the one mistake this layout still
allows.
