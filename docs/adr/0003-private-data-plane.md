# 3. Every Azure data service is reachable only through a private endpoint

Date: 2026-09-21

## Status

Accepted

## Context

PostgreSQL, Redis, Key Vault, the container registry and the report storage
account all hold something worth stealing. Azure exposes each of them on a
public endpoint by default, protected only by credentials. A leaked connection
string is then enough to reach the data from anywhere on the internet.

## Decision

All five services have `public_network_access` disabled and a private endpoint in
the `private-endpoints` subnet, with a private DNS zone linked to the VNet so the
usual hostnames resolve to private addresses from inside the cluster.

Two operations do not fit that model, because they use a data plane rather than
the Azure management API: writing secrets to Key Vault and creating blob
containers. For those, the module exposes a bootstrap flag
(`key_vault_public_network_access_enabled`, `storage_public_network_access_enabled`)
that opens the service to the operator's own IP for one apply, and is expected to
be turned back off afterwards.

## Consequences

Nothing outside the VNet can reach the data, including a GitHub-hosted runner.
That is why `deploy.yml` documents either flipping the bootstrap flags or moving
to a self-hosted runner inside the VNet, and why the first apply from a laptop
takes two passes.

Private DNS zones are cheap but easy to forget: a missing VNet link shows up as a
connection timeout with a perfectly valid hostname, which is the most confusing
failure mode in this stack.
