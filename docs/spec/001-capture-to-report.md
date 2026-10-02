# Spec 001: Core data model and the capture-to-report slice

Status: DRAFT v0.1, 2026-10-02. For discussion; nothing here is final until recorded as an ADR.

Basis: Lantern's architecture docs (`digitalreconsol/lantern`, branch `integration/lantern-workstation`, commit `b864cc0`: `docs/architecture/*` and ADR-001..006), plus the decisions in [rebuild-plan.md](../rebuild-plan.md).

## 1. Purpose

Define the smallest end-to-end slice that proves Cassie's core promise: a page is captured, preserved with provable integrity, verified later, and cited in a report whose evidence can be re-checked by anyone.

The slice is deliberately narrow. Every other app is ported only after this slice works, is tested, and passes the security baseline in section 9.

## 2. Non-goals for this slice

- Feeds, monitoring, identity lookups, stream recording, crawlers (ported later).
- SSO, hosted multi-tenancy, vendor billing.
- Search beyond simple lookups in the evidence list.
- A bootable OS image.
- Trusted external timestamping and signatures (listed under "Later", section 10).

## 3. What carries over from Lantern

Keep as written (Lantern Core contract invariants, by number):

| # | Invariant |
|---|---|
| 1 | Every tenant-owned object belongs to exactly one Organization and Workspace |
| 2 | Possessing a UUID never grants authorization |
| 3 | Research Session is research provenance, not login state |
| 4 | Source is the logical external thing; Capture is an observation of it |
| 5 | An AVAILABLE Capture is immutable |
| 6 | AVAILABLE Artifact bytes are immutable and cryptographically hashed |
| 7 | Derived Artifacts never replace their inputs |
| 8, 9 | Apps never write Core tables; Core never imports app code |
| 13 | Core records trusted user and application provenance for canonical writes |
| 14 | Collected material is untrusted and never inherits platform privileges |
| 18, 19 | Application identity does not imply Workspace access; background access is explicit, scoped, revocable and audited |

Also kept: typed Source/Capture/Artifact tables plus a `ResearchObject` reference spine (ADR-003); durable Jobs and a transactional Outbox on PostgreSQL (ADR-004); a `BlobStore` adapter boundary (ADR-005); no Case primitive yet (ADR-006); audit kept separate from research Activity.

Deferred from Lantern (not needed for this slice): Shared Corpus, shared search projection, Outbox consumers beyond basics.

## 4. Entities (slice scope)

Platform: User, Authentication Identity, Authentication Session, Organization (the tenant), Organization Membership, Workspace, Workspace Membership, Application Identity, Application Workspace Grant.

Research: Research Session, Research Object (spine), Source, Capture, Artifact, Capture-Artifact link, Artifact Derivation, Annotation (append-only, revisionable), Activity.

Infrastructure: Job, Outbox event, Audit event.

Research Identity (new in Cassie): a site plus the account name a user researched with. It exists for audit only; Cassie stores no passwords (section 8).

New in Cassie: **Report** (section 6).

Capture-Artifact links carry an opaque, namespaced role and an ordinal. Capture formats (decided by the owner, 2026-10-02) are a screenshot, an HTML snapshot, extracted text, and saved images and videos from the page. Initial roles for this slice: `capture/screenshot`, `capture/html-snapshot`, `capture/text`, `capture/metadata`, `capture/media-image`, `capture/media-video`. Saved media are separate Artifacts, each hashed and linked to the Capture that found them.

## 5. Roles and tenancy

From the rebuild plan: platform operator, tenant admin (instructor or organization admin), regular user.

- A tenant is an Organization. Organization membership alone does not grant access to a Workspace (kept from Lantern).
- Each regular user (for example a student) works in their own Workspace.
- Tenant admins and team leads need oversight of every Workspace in their tenant. **Decided (owner, 2026-10-02):** oversight is a distinct, explicit permission, separate from OWNER and strictly read-only (owner confirmed 2026-10-02; supervisor review comments are not planned). Its purpose is supervision, such as a team lead checking that their people follow policy and procedure, or an instructor reviewing student work. Every use is written to the audit log, and users are told it exists. This is a deliberate change from Lantern, where admin access did not silently imply research access, and it needs its own ADR.
- Role changes follow explicit escalation rules, each with a test. In Lantern, `add_workspace_member` (verified in `services/platform.py`) lets anyone with the manage-members permission, which ADMIN holds, assign any role including OWNER and overwrite an existing member's role, without checking organization membership.
- The platform operator manages tenants and the installation but has no access to tenant research data.

## 6. Reports

A Report is a document that cites evidence. Lantern's Core has no Report primitive; boards and exports lived in the Workbench app. So this is new.

Decided (owner, 2026-10-02):

- Drafts are owned by the web app's own store (app state), not by Core.
- Every citation records the Artifact id, its SHA-256, the Capture id and the capture time. A citation therefore pins exact bytes.
- **Export** produces a new Artifact in Core (for example PDF and HTML) with an Artifact Derivation whose inputs are the cited Artifacts, plus a machine-readable manifest of the citations. The exported report is itself immutable, hashed and verifiable.
- Editing a report after export creates a new export; the old one is never replaced (invariant 7).

## 7. The slice, step by step

1. **Sign in.** Local account with MFA. First-run setup requires a one-time setup token; it is not an open endpoint.
2. **Pick a Workspace and a Research Session.**
3. **Request a capture** of a URL. Core resolves the Source idempotently within the Workspace (same normalized URL, same Source) and creates a Capture in `PREPARING`, then enqueues a Job.
4. **Capture worker** claims the Job and runs an isolated, throwaway browser (section 8). It collects a screenshot, an HTML snapshot, extracted text, and a metadata record (final URL, redirect chain, response headers, timing, tool and version), and saves the images and videos the user selects or the capture policy includes.
5. **Preserve.** Each collected file is written through `BlobStore`; its Artifact moves `STAGED -> VERIFYING -> AVAILABLE` after size and SHA-256 are checked. The Capture links its Artifacts and becomes `AVAILABLE` (immutable). On failure it becomes `FAILED` with a reason.
6. **Verify.** The Evidence view shows the chain Source -> Capture -> Artifacts with who, when, which application and which tool version, and offers **Re-verify**, which re-reads the bytes and recomputes the hash.
7. **Annotate.** Append-only notes on captures or artifacts; a revision supersedes, never overwrites.
8. **Build and export a report** as described in section 6, then verify the exported report the same way.

Every canonical write records trusted user, application and Research Session context from the runtime, never from client-supplied fields.

## 8. Handling hostile content

- Captures run in an isolated, ephemeral browser (a fresh container per capture) with no access to Cassie's origin, secrets or internal network.
- Outbound access goes through one shared safe-fetch layer: allow only http(s); resolve DNS and block private, loopback, link-local, metadata and CGNAT ranges; re-validate every redirect hop; pin the resolved address to prevent DNS rebinding; hard limits on time, redirects and bytes; fail closed when DNS fails.
- Browser sub-requests are filtered by the same rules.
- Collected files are served only from a separate, cookieless origin or as downloads, with `X-Content-Type-Options: nosniff`, `Content-Disposition`, and a restrictive CSP. Collected content is never rendered inside the authenticated app origin.
- Artifact storage keys are generated by Core; user-supplied names never reach filesystem paths.
- **No credentials are stored (decided by the owner, 2026-10-02).** Cassie never stores passwords, MFA codes or TOTP seeds, and does not keep session cookies between captures. Users sign in by hand in the streamed capture browser, and the session ends with its container. There is no credential vault.
- **Never in evidence.** Captures begin after sign-in completes, so login forms are not screenshotted mid-entry; HTML snapshots exclude values of credential fields; request headers and network records are scrubbed of authorization and cookie values before storage; Job payloads and logs never carry secrets.
- **Login audit.** When a capture involves a signed-in site, the user records which research identity (site and account name) they used. An audit event stores the site, the account name, the time and the Cassie user, linked to the Capture, and tenant admins can see it through oversight. In this slice Cassie does not verify the account name; it is a label the user supplies.
- **Interactive sessions (proposed).** Captures that need a login run in an interactive capture session: a disposable container that lives for one sitting and is destroyed at the end, with all cookies and storage discarded. Fully automated captures use a fresh container each time.

## 9. Components for the slice

1. **Core**: API, worker, PostgreSQL, filesystem `BlobStore` behind the adapter.
2. **Capture worker**: runs isolated browser jobs; acts through a background application identity with an explicit Workspace grant.
3. **App**: React + TypeScript single-page app and its small API. Modules: Capture, Evidence, Report.

All three ship as containers, bind to loopback by default, use separate secrets per component, and run as non-root.

## 10. Later (not in this slice)

- Fuller archival formats such as WARC, alongside the screenshot and snapshot.
- Trusted external timestamping of captures and signed capture manifests.
- A hash-chained, tamper-evident audit log.
- Shared Corpus and promotion, for the monitoring app.
- S3-compatible `BlobStore`, SSO, PostgreSQL row-level security.

## 11. Acceptance criteria

Functional
- Capturing the same URL twice yields one Source and two Captures.
- Each Artifact verifies on write and on read; changing a stored byte makes Re-verify fail visibly.
- An exported report lists every citation with its hash, and its Derivation lineage shows all inputs.

Security (each is an automated test)
- Captures of `127.0.0.1`, private ranges, the cloud metadata address and a redirect or DNS rebind to those are refused.
- A malicious test page cannot run script in the app origin or read app cookies.
- A user cannot read, list or cite another user's Workspace; knowing a UUID does not help.
- Role-escalation attempts (admin to owner, cross-tenant membership) are refused.
- Oversight access by a tenant admin appears in the audit log.
- First-run setup cannot be performed without the setup token, and concurrent attempts create only one admin.
- Default compose or container setup publishes no port beyond loopback.

Quality
- Lint, type checks and the full test suite run in CI and pass; lockfiles and pinned image digests are in place; the end-to-end slice runs in CI against a local test site.

## 12. Open questions

Resolved 2026-10-02: report drafts live in the app (section 6); oversight is explicit, audited and strictly read-only (section 5); capture formats are screenshot, HTML, text, images and videos (section 4); captures run in disposable containers (section 8); Cassie stores no credentials, so there is no vault, no stored MFA seeds and no persisted session cookies (section 8).

1. Confirm the interactive capture session model: for captures that need a login, one disposable container per sitting instead of one per capture.
2. Size and time limits for saved video, and which video sources must be supported.
