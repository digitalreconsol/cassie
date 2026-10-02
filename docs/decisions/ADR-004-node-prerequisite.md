# ADR-004: Node.js is a development prerequisite

Status: Accepted, 2026-10-02 (foundation phase 1)

## Context

The phase 1 check says `./ctl check` must pass on a clean clone "with only Linux, Podman or Docker, uv and pnpm installed". uv installs Python by itself, but pnpm needs Node.js to run ESLint, TypeScript and Vitest.

## Decision

Node.js 24 is a listed prerequisite (`engines.node` in `package.json`). We do not rely on pnpm downloading a runtime.

## Consequences

- The README lists four prerequisites: Podman or Docker, uv, Node.js 24, pnpm.
- `scripts/verify-clean-clone.sh` uses a container with exactly those tools.
