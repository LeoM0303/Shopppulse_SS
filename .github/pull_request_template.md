## What and why

<!-- What changes, and what problem it solves. -->

## How it was verified

<!-- Commands run, environments touched, what you observed. -->

## Infrastructure changes

<!-- Paste the terraform plan summary (the "Plan: x to add, y to change, z to destroy" line), or write "none". -->

## Checklist

- [ ] CI is green
- [ ] README or module docs updated if behaviour changed
- [ ] No secrets, connection strings or state files in the diff
- [ ] Rollback for this change is understood (revert, `kubectl rollout undo`, or `terraform apply` of the previous state)
