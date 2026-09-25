# Security baseline

What a trainee or junior is expected to be able to point at and explain.
Nothing here is a substitute for a dedicated security review.

## Secrets

| Secret | Where it lives | Who reads it |
|--------|----------------|--------------|
| PostgreSQL DSN, Redis URL, Service Bus connection string, App Insights | Key Vault, copied into `shoppulse-secrets` at deploy time | API and worker pods |
| Blob access | none — shared keys are disabled, Workload Identity holds RBAC | worker writes, API reads |
| GitHub → Azure | OIDC federated credential, no client secret | `deploy.yml`, `terraform-plan.yml` |

`.env` files are gitignored. `gitleaks` scans the full history on every CI run.
A secret that was committed and later deleted is still a leaked secret.

## Identity and access

Each workload has its own user-assigned identity, federated to its Kubernetes
service account:

- `api` — Service Bus Data Sender, Key Vault Secrets User, Storage Blob Data **Reader**
- `worker` — Service Bus Data Receiver, Key Vault Secrets User, Storage Blob Data **Contributor**
- `keda` — Service Bus Data Receiver

The API cannot overwrite report snapshots. There is no storage account key to
rotate, because there is no key.

## Network

- Every data service is private-endpoint only. Public access is a bootstrap
  flag, not the steady state.
- Each subnet has an NSG that ends in an explicit deny. Postgres accepts 5432
  only from the AKS prefix.
- The only public address is ingress-nginx on 80/443. Port 80 only redirects.
- Cilium NetworkPolicies deny ingress to the worker and restrict the API and
  frontend to the ingress controller (and the frontend → API hop).

## Containers

- Images run as UID 10001 (API, worker) or 101 (frontend, `nginx-unprivileged`).
- Pods set `runAsNonRoot`, drop all capabilities, and disable privilege
  escalation. API and worker also use a read-only root filesystem.
- CI builds every changed image and fails the run on a **fixable** CRITICAL
  finding from Trivy. Checkov reviews Terraform on the same job.

## TLS

The Ingress terminates TLS on a certificate Terraform writes to
`shoppulse-tls`. The certificate is self-signed because there is no registered
domain. The secret name is the only contract, so swapping in cert-manager later
does not touch the rest of the stack.
