# Prompt 000: Full build, gated and resumable

Paste this into Claude Code in VS Code, opened on the `digitalreconsol/cassie` repo. It builds the whole improved suite, not just the foundation. It is designed to survive long runs: all state lives in the repo, so you can stop and re-run the same prompt at any time and it resumes.

---

You are building Cassie end to end: a browser-first, Linux-first OSINT research workstation that preserves evidence with provenance. Work autonomously, but only inside the gates below.

## Read first, in this order

1. `README.md`
2. `docs/rebuild-plan.md` (decisions; "Decided by the owner" is binding, "Defaults" change only with a written ADR)
3. `docs/spec/001-capture-to-report.md`
4. `docs/lessons-from-lantern.md`
5. `docs/prompts/001-foundation.md` (full requirements for Phase A; follow it as written)
6. `docs/build/PROGRESS.md` if it exists. It is the source of truth for where you are.

## Resumability

- Keep `docs/build/PROGRESS.md`: one line per task with status (todo, doing, done, blocked), the PR link, and the date. Update it in the same commit as the work.
- At the start of every session, read it and continue from the first task that is not done. Never redo finished work; never mark something done without its check passing.
- If your context is getting large, finish the current task, update PROGRESS.md, commit, and stop with a one-paragraph handoff. The owner will re-run this prompt.

## Working rules (apply to everything)

- One branch and one PR per task. Never push to `main`. Merge only when the task's checks are green and a fresh reviewer agent (one that did not write the code) has reviewed the diff against `docs/lessons-from-lantern.md` and the security checklist, and its findings are fixed or written up.
- Tests before or with code. No feature merges without tests; no security rule weakened to pass a test.
- Decisions not in the docs become short ADRs in `docs/decisions/`.
- Pin everything: lockfiles, image digests, action SHAs. No secrets in the repo.
- Linux first, rootless Podman first, Docker also works. No PowerShell.
- Every app uses the shared libraries, the app template and the design system. If an app needs something the foundation lacks, add it to the foundation, not to the app.
- Follow the spec's hostile-content rules for anything that touches the web: safe-fetch for every outbound request, fresh disposable container per capture, no stored credentials, separate cookieless origin for captured content.

## Stop conditions

Stop and report (do not guess) if:

- a security rule in the docs conflicts with a requirement,
- a check cannot be made to pass after a reasonable attempt, and say what you tried,
- a task needs something only the owner can supply (an account, a legal decision, network access you do not have),
- you would have to change a "Decided by the owner" item.

## Phases

### Phase A: Foundation
Do everything in `docs/prompts/001-foundation.md` (layout, CI, shared libraries, app template, Core skeleton, Quadlet deployment). Gate: its acceptance checks all pass.

### Phase B: Vertical slice (Scout, Codex, Workbench)
Implement `docs/spec/001-capture-to-report.md` section by section:

1. Capture worker: fresh container per capture, streamed capture browser, screenshot, HTML snapshot, extracted text, metadata, saved images. Interactive capture sessions with login audit (site, account name, time, user; never credentials).
2. Media acquisition (section 7a): browser-observed capture, extractor tool, playback recording fallback; originals never re-encoded; size and time limits and quotas as specified; canary test suite for YouTube and TikTok (required) and the best-effort Chinese platforms (report, do not fail the build).
3. Scout app: start a capture, watch the streamed browser, see results.
4. Codex app: read-only verification of Source, Capture, Artifact, hashes.
5. Workbench app: report drafts in the app, pinned citations, export as a new immutable Artifact with Derivation lineage to cited evidence.
6. Roles: platform operator, tenant admin, regular user; read-only audited oversight; per-user quotas.

Gate: the spec's acceptance criteria (functional, security tests, quality) all pass, plus an end-to-end test that runs capture, verify and export against a local test web server, and a tamper test showing that a modified artifact is detected.

### Phase C: Port the remaining apps, one at a time
In this order, each on the shared foundation, each with its own tests and security review: Watchtower, Crawler (merge of Pathfinder and Scanner; one implementation), Matchbook, Observatory. Rebuild each from its purpose in `docs/lessons-from-lantern.md` and the spec, not by copying Lantern code. Observatory must pass an ffmpeg protocol allowlist. Matchbook must pass argument-injection tests. Gate per app: tests, security checklist, accessibility checks (axe), docs.

### Phase D: Packaging and classroom readiness
- Container images for every service, non-root, read-only filesystem, no capabilities, scanned in CI.
- Quadlet units and `ctl` commands for install, upgrade, backup and restore, per-student workspace reset and snapshot, deletion on request.
- Per-student resource limits, controlled egress configuration (proxy or VPN hook), and low-bandwidth streaming settings.
- An `docs/operations/` guide for the owner: install on one Linux VM, create a class, size the server by concurrent students.
- An `ADR` and a plan (not an implementation) for the VM image, which stays out of scope until containers run cleanly on Linux.

Gate: a fresh Linux VM (or container with systemd) installs from the docs alone, runs an end-to-end class scenario with two students and one instructor, and the oversight and isolation tests pass.

### Phase E: Hardening and handoff
- Run the full security checklist against the finished system and record results in `docs/security/review-001.md`. List what was verified by running it and what was only reviewed by reading.
- Update README, rebuild-plan (mark decisions done) and lessons docs to match reality.
- Write `docs/build/HANDOFF.md`: what is built, what is not, known gaps, the open items still needing the owner (licensing review of bundled tools, final project name, government customer type, class size), and recommended next steps.

## Out of scope for this prompt

Pilot with analysts, the bootable VM image, hosted multi-tenant SaaS, FedRAMP/CJIS/FIPS work, SSO. Note where the design leaves room for them; do not build them.

## Reporting

After each merged task, add one line to PROGRESS.md. When you stop (done, blocked, or out of context), end with: what finished, what is next, anything blocked and what you need from the owner.
