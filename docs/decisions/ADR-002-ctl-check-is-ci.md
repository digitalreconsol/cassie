# ADR-002: `./ctl check` targets are the CI jobs

Status: Accepted, 2026-10-02 (foundation phase 1)

## Context

In Lantern, ruff and mypy were configured but never run, and CI was paused. The owner's GitHub Actions quota has run out before, so CI may not always be available. The prompt requires that `./ctl check` runs the same commands as CI.

## Decision

- `./ctl check` is split into named targets (phase 1: `lint`, `types`, `test`). With no argument it runs all of them.
- Every CI job runs `./ctl check <target>` and nothing else of substance. CI never has its own copy of a lint, type or test command.
- New gates (audit, secret scan, integration tests, image scan) are added as new `ctl` targets first, then wired into CI.
- Each run starts with `uv sync --locked` and `pnpm install --frozen-lockfile`, so a stale lockfile fails the check.

## Consequences

- When CI cannot run, `./ctl check` on a clean checkout is the gate, and a PR says so.
- `scripts/verify-clean-clone.sh` runs `./ctl check` on committed content in a fresh container to catch "works on my machine".
