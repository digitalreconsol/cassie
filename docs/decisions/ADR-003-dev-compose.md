# ADR-003: Dev compose: Postgres unpublished, generated dev secrets

Status: Accepted, 2026-10-02 (foundation phase 1)

## Context

Lantern published every service port and Postgres (with a default password) on all interfaces. The prompt requires loopback binds by default, Postgres never published, per-container secrets, and a dev-only compose file.

## Decision

- `deploy/compose/compose.dev.yaml` is for development only. Production uses Quadlet units (phase 4).
- Postgres is not published at all, not even on 127.0.0.1. It sits on an `internal` network. Developers use `./ctl psql`; integration tests start their own throwaway Postgres container (phase 3, `cassie_testing`).
- Anything that is published binds to `${CASSIE_BIND_ADDR:-127.0.0.1}`.
- `./ctl up` generates a random dev Postgres password in `var/secrets/` (git-ignored, directory mode 700) and passes it as a compose secret. No password is ever written in the repo or in `.env.example`.
- Postgres runs as its own uid with a read-only root filesystem, all capabilities dropped and `no-new-privileges`.

## Consequences

- No default credentials exist to leak or forget to change.
- Tools on the host that expect `localhost:5432` will not work; use `./ctl psql` or a container on the `backend` network.
- The dev secret file is world-readable (0644) inside a private directory, because rootful Docker bind-mounts compose file secrets as-is and the container user must read it. Production uses Podman secrets instead.
