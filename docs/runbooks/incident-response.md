# Incident response

What to do when an alert fires or a user reports that ShopPulse is broken.
Written to be followed at 3am by someone who did not build the system.

## Severity

| Severity | Meaning | Response |
|----------|---------|----------|
| Sev 1 | Dashboard or event submission is down for everyone | Start immediately, roll back first and investigate afterwards |
| Sev 2 | Degraded: stale dashboard, slow responses, one replica crash-looping | Start within the hour, investigate before changing anything |
| Sev 3 | No user impact yet: disk filling, error rate up, drift detected | Next working day |

## First five minutes

Set the context once, everything below reuses it:

```bash
az login
az aks get-credentials --resource-group shoppulse-dev-rg --name shoppulse-dev-aks --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl config set-context --current --namespace shoppulse
```

Then answer three questions, in this order.

**Is the application up?**

```bash
kubectl get pods
kubectl get ingress
IP="$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
curl -sSk -o /dev/null -w '%{http_code}\n' --resolve "shoppulse.local:443:$IP" https://shoppulse.local/api/dashboard
```

`--resolve` because the dev host has no public DNS, `-k` because its certificate
is self-signed. With a real domain both flags disappear.

**Did anything change recently?** A deployment is the most likely cause of a
sudden failure. Check the Deployments tab of the repository, and:

```bash
kubectl rollout history deployment/api
kubectl describe deployment/api | grep -i image
```

**What does the platform say?** Open the Log Analytics workspace
(`shoppulse-dev-logs`) and run the queries in the next section.

## Queries that answer the common questions

Run these in Log Analytics > Logs, scoped to the workspace.

Which pods are restarting, and how often:

```kql
KubePodInventory
| where Namespace == "shoppulse"
| summarize restarts = max(PodRestartCount), last_seen = max(TimeGenerated) by Name, PodStatus
| order by restarts desc
```

What the application actually logged, newest first:

```kql
ContainerLogV2
| where PodNamespace == "shoppulse"
| where LogMessage has "ERROR" or LogMessage has "Traceback"
| project TimeGenerated, PodName, LogMessage
| order by TimeGenerated desc
| take 100
```

Failed requests and their exceptions, from Application Insights:

```kql
requests
| where success == false
| summarize failures = count() by name, resultCode
| order by failures desc
```

```kql
exceptions
| project timestamp, cloud_RoleName, type, outerMessage, operation_Id
| order by timestamp desc
| take 50
```

An operation end to end, once an `operation_Id` is known from the query above:

```kql
union requests, dependencies, traces, exceptions
| where operation_Id == "<operation_Id>"
| order by timestamp asc
```

## Scenarios

### Dashboard shows FALLBACK (db) instead of LIVE (cache)

The worker is not recomputing the summary, or Redis is unreachable. The API is
healthy, so this is Sev 2.

1. `kubectl get pods -l app=worker` — KEDA keeps the worker at zero replicas
   when the queue is empty, so **zero pods with an empty queue is normal**.
2. Check the queue: `az servicebus queue show --resource-group shoppulse-dev-rg --namespace-name <ns> --name sales-events --query countDetails`.
   Messages piling up with no worker means KEDA is not scaling — check the
   `keda-servicebus` service account annotation and the federated credential
   subject.
3. Messages being consumed but the dashboard staying stale means Redis: look for
   connection errors in the worker logs, then confirm the private endpoint
   resolves from inside the cluster:
   `kubectl run dns-check --rm -it --image=busybox --restart=Never -- nslookup <redis-host>`.

### API pods crash-looping

```bash
kubectl logs deployment/api --previous --tail=100
kubectl describe pod -l app=api | tail -30
```

Most likely causes, in order: a bad `DATABASE_URL` after a secret change, the
PostgreSQL private endpoint not resolving, or an image that was never pushed.
`describe` distinguishes the last one immediately (`ImagePullBackOff`).

### Nothing answers on the public address

Sev 1. The ingress controller is the only way in, so start there rather than at
the application.

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
kubectl get pods -n ingress-nginx
kubectl logs deployment/ingress-nginx-controller -n ingress-nginx --tail=100
kubectl describe ingress shoppulse -n shoppulse
```

What the symptoms mean:

- **No external IP on the controller service** — Azure has not assigned a public IP. Check the service events and the subscription's public IP quota.
- **503 from the controller** — the Ingress resolved but its backend has no ready endpoints. `kubectl get endpoints api frontend -n shoppulse` tells you which one.
- **404 from the controller** — the request arrived with a host the Ingress does not serve. Compare the `Host` header against `ingress_hostname`.
- **TLS error** — check that the `shoppulse-tls` secret exists in the `shoppulse` namespace. It is created by Terraform, so a namespace that was deleted and recreated by hand will be missing it: `terraform apply` puts it back.

If a connection times out with no controller logs at all, suspect the NSG
rather than Kubernetes — nothing reached the cluster:

```bash
az network nsg rule list --resource-group shoppulse-dev-rg --nsg-name shoppulse-dev-aks-nsg -o table
```

### A migration job failed

Sev 1 during a deploy, because the pipeline stops before the rollout and the
previous version keeps running — which is the good outcome.

```bash
kubectl get jobs -n shoppulse
kubectl logs job/db-migrate-<tag> -n shoppulse --tail=200
```

Fix the revision and deploy again. Do not "unblock" the pipeline by deleting the
job: the schema is either migrated or it is not, and a rollout against a
half-migrated database is worse than a stopped deploy.

If a migration succeeded but the new image is broken, rolling back the image is
safe only when the migration was backwards compatible. If it was not, the
options are a `downgrade` revision or a point-in-time restore — see below.

### Roll back a bad deployment

This is the first action for any Sev 1 caused by a release.

```bash
kubectl rollout undo deployment/api
kubectl rollout undo deployment/frontend
kubectl rollout undo deployment/worker
kubectl rollout status deployment/api --timeout=5m
```

`deploy.yml` already does this automatically when its smoke test fails. To pin a
known-good version instead, re-run the deploy workflow with `image_tag` set to
the previous `sha-<commit>`.

### PostgreSQL storage above 85%

Sev 2 that becomes Sev 1 when it reaches 100%, and storage cannot be shrunk
afterwards — growing it is a one-way door, so check what is consuming space
first.

```sql
SELECT pg_size_pretty(pg_total_relation_size('sales_events'));
SELECT count(*), min(occurred_at), max(occurred_at) FROM sales_events;
```

If the growth is legitimate, raise `postgres_storage_mb` in the environment's
tfvars and apply. If it is old data, delete events past the retention the
dashboard needs — it only ever queries the last 24 hours.

### Restore the database

Point-in-time restore creates a **new** server; it never overwrites the existing
one, which is what makes it safe to run during an incident.

```bash
az postgres flexible-server restore \
  --resource-group shoppulse-dev-rg \
  --name shoppulse-dev-pg-restored \
  --source-server shoppulse-dev-pg \
  --restore-time "2026-09-21T14:30:00Z"
```

Then verify the data on the restored server, update `database-url` in Key Vault
to point at it, and re-run the deploy workflow so pods pick up the new secret.
The retention window is `postgres_backup_retention_days` — 7 days in dev, 35 in
prod — so a restore older than that is not possible.

### PostgreSQL failover in production

Production runs zone-redundant HA with a standby in another zone. A zone
failure fails over automatically in tens of seconds; the hostname does not
change, but in-flight connections are dropped, so expect a burst of connection
errors from the API and the worker followed by a recovery.

```bash
az postgres flexible-server show --resource-group shoppulse-prod-rg --name shoppulse-prod-psql \
  --query "{state:state, ha:highAvailability}" -o json
```

If `highAvailability.state` is not `Healthy` after a failover, the standby is
being rebuilt — the primary is serving, but a second zone failure is not
survivable until it finishes.

Test this deliberately rather than during an incident:

```bash
az postgres flexible-server restart --resource-group shoppulse-prod-rg \
  --name shoppulse-prod-psql --failover Planned
```

Dev has no standby by design (Burstable SKUs cannot run HA), so there its
recovery path is the point-in-time restore above.

### Report snapshots stopped appearing

Sev 3: no user impact. Snapshots are a side channel, and the worker logs
`Could not store the report snapshot` and carries on. Check the worker logs for
that message, then confirm the worker identity still holds Storage Blob Data
Contributor on the account and that `REPORTS_STORAGE_ACCOUNT_URL` is set in the
config map. An empty value disables the feature by design.

### Infrastructure drift issue opened overnight

`drift.yml` found that Azure no longer matches the code. Read the plan in the
issue and decide which side is wrong: apply the code to revert a manual portal
change, or bring the code up to date if the change was intentional. Never close
the issue without doing one of the two.

## After the incident

While it is still fresh, write down what broke, what the user-visible impact was,
how it was found, and what would have caught it earlier. If the answer to the
last question is a new alert, add it to `modules/monitoring/main.tf` in the same
pull request as the fix. If a step of this runbook was wrong or missing, fix the
runbook — that is the cheapest possible improvement to the next incident.
