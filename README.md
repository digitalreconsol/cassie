# Cassie

Working name. A browser-first, Linux-first OSINT research workstation that preserves evidence with provenance.

Cassie is the planned successor to [Lantern](https://github.com/digitalreconsol/lantern), which stays untouched as a reference prototype. This repo starts from a clean history and ports ideas deliberately, not code wholesale.

## Status

Foundation in progress (see [docs/prompts/001-foundation.md](docs/prompts/001-foundation.md)). Phase 1, repo layout and tooling, is done. There are no features yet.

## Setup

Cassie is developed on Linux. You need:

- Podman (preferred, rootless) or Docker, with the `compose` subcommand
- [uv](https://docs.astral.sh/uv/) 0.12 or newer (it installs Python 3.13 for you)
- Node.js 24
- pnpm 12 (`npm install -g pnpm@12` or `corepack enable`)

Then:

```sh
git clone https://github.com/digitalreconsol/cassie.git
cd cassie
./ctl check        # installs locked dependencies, then lint, types and tests
./ctl up           # dev stack: PostgreSQL only for now, nothing published
./ctl psql         # psql inside the dev database container
./ctl down
```

`./ctl help` lists every command. `./ctl check` runs exactly what CI runs ([ADR-002](docs/decisions/ADR-002-ctl-check-is-ci.md)).

Optional: install the git hooks with `uv tool install pre-commit && pre-commit install`.

To prove a commit passes on a clean machine, run `scripts/verify-clean-clone.sh`. It runs `./ctl check` on the committed tree in a fresh container that has only Node, uv and pnpm.

## Layout

```
core/            Core service (FastAPI, SQLAlchemy, Alembic; PostgreSQL only)
libs/py/         shared Python libraries: safefetch, auth, logging, testing
libs/ts/         shared TypeScript packages: ui, escape, api-client
apps/_template/  app starter
deploy/quadlet/  Podman Quadlet units (production)
deploy/compose/  dev-only compose file
docs/            plan, spec, decisions (ADRs), prompts
scripts/         helpers called by ctl or CI
ctl              the single entry command
```

## Documents

- [docs/lessons-from-lantern.md](docs/lessons-from-lantern.md): what the Lantern prototype got right, and what to fix. Based on a static code audit on 2026-10-02.
- [docs/rebuild-plan.md](docs/rebuild-plan.md): plan and decisions.
- [docs/spec/001-capture-to-report.md](docs/spec/001-capture-to-report.md): spec for the first vertical slice (Core data model, roles, capture to verified report, acceptance criteria).
- [docs/decisions/](docs/decisions/README.md): architecture decision records.
- [docs/prompts/001-foundation.md](docs/prompts/001-foundation.md): the prompt for building the technical foundation.
