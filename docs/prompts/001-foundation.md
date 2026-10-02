# Prompt 001: Technical foundation

Paste this into Claude Code in VS Code, opened on the `digitalreconsol/cassie` repo. It builds the foundation only. It does not build the capture feature.

---

You are building the technical foundation for Cassie, a browser-first, Linux-first OSINT research workstation that preserves evidence with provenance.

## Read first, in this order

1. `README.md`
2. `docs/rebuild-plan.md` (decisions; "Decided by the owner" is binding, "Defaults" can change only with a written reason)
3. `docs/spec/001-capture-to-report.md` (the first slice; sections 1-12)
4. `docs/lessons-from-lantern.md` (mistakes not to repeat)

Do not read or copy code from the Lantern repo wholesale. If you need an idea from it (for example Watchtower's `fetch_safety.py`), port it deliberately with tests.

## Scope of this task

Foundation only: repo layout, tooling, CI, shared libraries, an app template, and a hardened Core skeleton. No capture worker, no video acquisition, no report UI. Stop when the acceptance checks below pass.

## Working rules

- Work on a branch per phase (`foundation/01-layout`, and so on) and open a PR for each. Do not push to `main`.
- After each phase, stop, run the checks, and summarize what passed and what did not. Do not start the next phase until the checks are green.
- Anything you decide that is not in the docs goes into `docs/decisions/ADR-NNN-title.md` (context, decision, consequences). Keep each under one page.
- Do not weaken a security rule to make a test pass. If a rule seems wrong, write it up and ask.
- Pin everything: lockfiles committed, container images by digest, GitHub Actions by commit SHA.
- Linux first. Shell scripts are POSIX/bash; no PowerShell. Develop for rootless Podman; Docker must also work.
- No secrets in the repo. Provide `.env.example` only.

## Phase 1: Layout and tooling

Monorepo:

```
cassie/
  core/                 # Core service (FastAPI, SQLAlchemy, Alembic), PostgreSQL only
  libs/
    py/                 # shared Python libraries (uv workspace members)
      cassie_safefetch/
      cassie_auth/
      cassie_logging/
      cassie_testing/
    ts/                 # shared TypeScript packages (pnpm workspace)
      ui/               # design system (React + TypeScript)
      escape/           # safe rendering helpers
      api-client/       # generated from Core's OpenAPI schema
  apps/
    _template/          # app template (phase 4)
  deploy/
    quadlet/            # Podman Quadlet / systemd units
    compose/            # dev-only compose file, loopback binds
  docs/
  scripts/
  ctl                   # single entry command (bash)
```

- Python 3.13, `uv` workspace, one lockfile. Ruff (lint and format), mypy strict on `libs/` and `core/`, pytest.
- TypeScript strict, pnpm workspace with committed lockfile, ESLint with `no-danger`-style rules (forbid `dangerouslySetInnerHTML` and `innerHTML`), Vitest.
- `ctl` subcommands: `ctl check` (lint + types + tests, everything CI runs), `ctl up`, `ctl down`, `ctl logs`, `ctl db-reset` (dev only). `ctl check` must run the same commands as CI.
- pre-commit config with ruff, mypy, eslint, gitleaks.

Check: `./ctl check` passes on a clean clone with only Linux, Podman or Docker, uv and pnpm installed.

## Phase 2: CI

GitHub Actions, one workflow, jobs run in parallel:

- lint and type check (Python and TypeScript)
- unit tests with coverage report (fail under 80% on `libs/`)
- integration tests against a real PostgreSQL container (no SQLite)
- dependency audit (`pip-audit`, `pnpm audit`) and secret scan (gitleaks)
- container image build, scan with Trivy, fail on HIGH or CRITICAL with a fix available
- Dependabot or Renovate for lockfiles and image digests

Note: the owner's Actions quota ran out on Lantern. If CI cannot run, `./ctl check` is the gate; say so in the PR.

Check: a deliberately failing lint, test, and secret each turn CI red in a throwaway PR (describe the evidence; do not leave the failures in).

## Phase 3: Shared libraries (test-first)

Write tests before code. Each library has a README with its threat model in five lines or fewer.

1. **`cassie_safefetch`**: every outbound HTTP request in Cassie goes through this. Requirements:
   - allow only http and https; reject userinfo in URLs
   - resolve DNS, then connect to the resolved IP (pin it, so DNS rebinding cannot swap it)
   - block loopback, private, link-local, multicast, reserved ranges, cloud metadata addresses (IPv4 and IPv6, including IPv4-mapped IPv6)
   - treat DNS failure as blocked, never as public
   - follow redirects manually, re-validating every hop; cap hops
   - cap response bytes and total time; stream, never buffer unbounded
   - configurable allowlist/denylist, default deny-private
   - tests include: redirect to 127.0.0.1, redirect to metadata IP, decimal/octal/hex IP forms, IPv6 forms, DNS rebinding simulation, oversized body, slow body
2. **`cassie_auth`**: password hashing (scrypt or argon2id), random tokens stored only as hashes, constant-time compare, TOTP MFA, session handling, per-app scoped short-lived tokens (no passing the user's session token to apps). Role model per the spec: platform operator, tenant admin, regular user. Role-escalation rules (no one can grant a role above their own) enforced in one place with exhaustive tests, including the Lantern bug where an admin could assign OWNER.
3. **`cassie_logging`**: structured JSON logs, request IDs, a redaction filter that removes passwords, tokens, cookies and `Authorization` headers. Test that secrets never reach log output.
4. **`cassie_testing`**: fixtures for Postgres, a fake clock, and a local HTTP test server (for safe-fetch tests).
5. **`ts/escape` and `ts/ui`**: React components render text only by default; a documented, linted escape hatch for anything else. A small design system (button, input, table, dialog, form field) with keyboard support and visible focus. Section 508 / WCAG 2.2 AA is the bar; run axe in tests.
6. A single `utcnow()` and ID generation helper in one place.

Check: all libraries pass tests; mutation of the safe-fetch blocklist (remove one range) makes a test fail.

## Phase 4: Core skeleton and app template

**Core** (`core/`), implementing only what the spec's data model needs for the foundation:

- Entities from spec section 2: tenants, users, workspaces, sources, captures, artifacts, activity, audit log. Alembic migrations from day one.
- Artifacts are immutable at the database level (no UPDATE or DELETE path in the service layer; add a DB trigger that rejects them). SHA-256 recorded on write and verified on read. BlobStore with server-generated keys, symlink-safe containment, atomic writes.
- **First-run setup**: no unauthenticated bootstrap endpoint. First admin is created by `ctl bootstrap`, which prints a one-time setup token; creation is atomic and works exactly once.
- **Authorization at the service layer**: every service function takes an actor and checks permission. A test enumerates all service functions and fails if any lacks a permission check.
- Oversight: tenant admin read access to other workspaces, read-only, every access written to the audit log, with a test that proves oversight cannot write.
- Audit log is append-only; includes login events (site, account name, time, user) per the spec, never credentials.
- OpenAPI schema published; TypeScript client generated from it in CI (fail if the generated client is out of date).

**App template** (`apps/_template/`): a copyable starter with its own backend, a React frontend using `ts/ui`, a strict CSP, origin-checked messaging, per-app secret, its own Dockerfile (non-root, read-only filesystem, no capabilities), health endpoint, tests, and a README saying how to copy it. `ctl new-app <name>` copies it and renames things.

**Deployment**: Quadlet units for Core, PostgreSQL and one example app. All ports bind to 127.0.0.1 by default; nothing is published unless configured. Postgres is never published. Each container gets its own secret (Podman secrets), not a shared volume.

Check: the acceptance list below.

## Acceptance checks (all must pass)

Security:
- [ ] Fresh install has no unauthenticated way to create the first admin, and `ctl bootstrap` works once only
- [ ] No service listens on a non-loopback address by default; Postgres is unreachable from outside the container network
- [ ] A regular user cannot read another user's workspace; an admin can, read-only, and the access is audited
- [ ] No role can grant a role above its own
- [ ] All safe-fetch tests above pass, including rebinding and redirect cases
- [ ] Attempting to modify or delete an Artifact (service layer and raw SQL) fails
- [ ] Secret scan finds nothing; logs contain no secrets in tests

Quality:
- [ ] `./ctl check` passes locally and in CI
- [ ] Lockfiles, image digests, and action SHAs are all pinned
- [ ] Every ADR you wrote is linked from `docs/decisions/README.md`
- [ ] README has accurate setup steps, verified on a clean machine or container

## Finish

Open a final PR titled "Foundation complete" with: what was built, which checks passed, anything skipped and why, and the three things you would do next. Do not start on capture, video, or reports; those are prompt 002.
