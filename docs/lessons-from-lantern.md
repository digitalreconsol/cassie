# Lessons from Lantern

Source: static review of `digitalreconsol/lantern` branch `integration/lantern-workstation` at commit `b864cc0`, 2026-10-02. Nothing was run. Findings marked "not re-checked" came from review passes and were not confirmed by hand.

## What worked and should carry over

- **Core owns the research record.** Apps are replaceable; durable shared research lives in one place behind a versioned contract.
- **Evidence chain.** Source -> Capture -> Artifact, with SHA-256 hashes and an audit trail. Original material is never silently replaced; derivatives keep lineage.
- **Written architecture decisions** (ADRs) and a boundary test that keeps application vocabulary out of Core.
- **Auth basics.** Random tokens stored only as hashes, scrypt with per-user salt, constant-time compare, one-time launch tickets bound to an app.
- **Storage.** Server-generated keys, symlink-safe path containment, atomic writes, hash verified on write and read.
- **Electron hardening.** `contextIsolation`, `sandbox`, no `nodeIntegration`, narrow preload surface, strict CSP in the shell.
- **Watchtower's `fetch_safety.py`**: scheme checks, DNS resolution check, manual redirect re-validation, byte caps. Reuse as the shared safe-fetch library.
- **Codex**: a read-only view that proves evidence was actually persisted.

## What to fix by design, not by patch

| Area | Lantern behavior | Direction for Cassie |
|---|---|---|
| First run | Unauthenticated, non-atomic bootstrap endpoint on a published port | Setup token or local-only first-boot flow; atomic creation |
| Network exposure | All service ports and Postgres (default password) published on all interfaces | Bind to loopback by default; nothing published unless configured |
| App credentials | One shared secrets volume readable by every app; user session token handed to apps | Per-app secrets; app-scoped, short-lived tokens |
| Authorization | App grants enforced on one route only (not re-checked) | Enforce grants uniformly at the service layer |
| Roles | Workspace admin can assign OWNER (not re-checked) | Explicit role-escalation rules and tests |
| Outbound fetch | Host checked once, then redirects followed; DNS failure treated as public | One shared safe-fetch library used everywhere |
| Subprocesses | User input passed to CLI tools without `--`; ffmpeg without protocol whitelist | Argument validation and allowlists in one wrapper |
| Frontends | Many hand-rolled `innerHTML` renders; one escape helper missing quote handling | One frontend stack with safe-by-default rendering; CSP on every app |
| Cross-frame messaging | No origin checks; posts to `*` (not re-checked) | Origin-checked message channel |
| Dependencies | No npm lockfiles; floating image tags; no scanning | Lockfiles, pinned digests, dependency and secret scanning in CI |
| Quality gates | ruff/mypy configured but never run; thin tests; CI paused | Lint, types, tests, and CI green before features |
| Duplication | Scanner and Pathfinder crawler files identical; `utcnow()` defined 14 times | Shared libraries and an app template |
| Platform | PowerShell-first scripts, Docker Compose assumed | Linux-first, one `ctl` command, container images as the unit of deployment |
| Housekeeping | Dead routes, stale docs, legacy apps kept in tree | Remove or archive as you go; docs updated with code |

## Process lessons

- Breadth came before depth: about ten apps, most thinly tested. Build one workflow properly first.
- Keep docs and branch status current; several READMEs disagreed with the code.
- Decide hosting and deployment model before building features that depend on it.
