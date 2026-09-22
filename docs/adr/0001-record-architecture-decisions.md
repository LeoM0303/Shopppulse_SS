# 1. Record architecture decisions

Date: 2026-09-21

## Status

Accepted

## Context

The infrastructure in this repository has a handful of choices that look
arbitrary from the outside: a single Terraform root, private endpoints for
everything, feature flags instead of separate stacks. Every one of them came out
of a problem that is invisible in the final code. Reviewers kept asking the same
questions, and the answers only lived in chat history.

## Decision

Decisions that are expensive to reverse are written down as numbered records in
`docs/adr/`, in the same pull request as the change they describe. Records are
immutable: a decision that no longer holds gets a new record that supersedes it.

Anything that a `git revert` can undo does not need a record.

## Consequences

Reviewing infrastructure changes gets cheaper, because the reasoning arrives with
the diff instead of being reconstructed afterwards. The cost is one short file
per significant change, and the discipline to not edit old records.
