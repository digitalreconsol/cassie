# Rebuild plan (DRAFT)

Status: proposal for discussion. Items under "Open decisions" are not decided. Nothing here should be treated as final until it is moved to an ADR.

## Goal

A browser-first, Linux-first OSINT research workstation where every capture is preserved with provenance and can be verified later. Primary use: the owner's own investigative work, reachable remotely. Possible later: deployment into other organizations' environments (including government), and a hosted offering.

## Proposed principles

1. **Evidence integrity first.** Keep the Source -> Capture -> Artifact model, hashing and audit trail.
2. **Secure by default.** Loopback binds, per-app secrets, no unauthenticated setup, safe fetch everywhere.
3. **One foundation.** Shared app template and libraries (auth client, safe fetch, escaping, logging, tests).
4. **One frontend stack and design system** with accessibility built in.
5. **Containers as the unit of deployment** (rootless Podman friendly), usable in dev, in a VM image, and in a customer's own environment.
6. **Tests and CI before features.**

## Keep / rebuild / retire (proposed)

- **Keep (port deliberately):** Core domain model and contract, ADRs, evidence chain, launch-ticket idea, storage layer, Watchtower safe-fetch.
- **Rebuild on the new foundation:** each app's backend scaffold and frontend; the shell as browser-first UI.
- **Retire:** legacy apps, Windows-only scripts, dead routes.

## Phases

0. **Spec and decisions.** Fill in the open decisions below; record them as ADRs.
1. **Foundation.** Repo layout, CI, shared libraries, app template, Core with hardened defaults.
2. **Vertical slice.** Capture a page -> preserve -> verify -> add to a report, end to end, with tests.
3. **Port apps one at a time** onto the foundation, in priority order.
4. **Packaging.** Container images, `ctl` command, then a VM image.
5. **Pilot** with two or three real analysts.

## Open decisions

- [ ] Target users and the first workflow to perfect
- [ ] Deployment modes: personal remote instance, customer-hosted, vendor-hosted
- [ ] Core database: PostgreSQL or SQLite for single-user installs
- [ ] How collection runs: server-side browser streamed to the user vs. local collection
- [ ] Frontend stack and design system
- [ ] Which Lantern apps to port, and in what order
- [ ] Authentication: local accounts only, or SSO/MFA from the start
- [ ] Licensing and third-party tool review before redistributing anything
- [ ] Final project name (Cassie is a working name)

## Non-goals (proposed)

- No bootable OS image until the application runs cleanly in containers on Linux.
- No hosted multi-tenant service until the security baseline and legal review are done.
