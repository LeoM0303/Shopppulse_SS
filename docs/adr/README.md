# Architecture decision records

Short notes on decisions that were hard to reverse or that a newcomer would
otherwise have to reconstruct from the Terraform code.

One file per decision, numbered, never rewritten. When a decision stops being
true, add a new record and mark the old one superseded — the trail of what we
believed at the time is the useful part.

| ADR | Decision | Status |
|-----|----------|--------|
| [0001](0001-record-architecture-decisions.md) | Keep decisions in the repository as ADRs | Accepted |
| [0002](0002-single-terraform-root.md) | One Terraform root with feature flags instead of two stacks | Accepted |
| [0003](0003-private-data-plane.md) | Every Azure data service is private-endpoint only | Accepted |
| [0004](0004-workload-identity-over-secrets.md) | Workload Identity instead of connection strings where the service supports it | Accepted |
| [0005](0005-remote-state-in-azure-storage.md) | Terraform state in Azure Storage, one key per environment | Accepted |
| [0006](0006-azure-monitor-for-observability.md) | One Log Analytics workspace, Container Insights and Application Insights | Accepted |
| [0007](0007-blob-storage-for-report-snapshots.md) | Report snapshots in Blob Storage with a lifecycle policy | Accepted |
