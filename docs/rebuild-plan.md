# Rebuild plan (DRAFT)

Status: draft. The "Decisions" section separates what the owner decided, what are working defaults, and what is still open. Nothing here is final until it is moved to an ADR.

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

0. **Spec and decisions.** Close the remaining open decisions; record all decisions as ADRs.
1. **Foundation.** Repo layout, CI, shared libraries, app template, Core with hardened defaults.
2. **Vertical slice.** Capture a page -> preserve -> verify -> add to a report, end to end, with tests.
3. **Port apps one at a time** onto the foundation, in priority order.
4. **Packaging.** Container images, `ctl` command, then a VM image.
5. **Pilot** with two or three real analysts.

## Decisions

Updated 2026-10-02.

### Decided by the owner

- **First workflow to perfect:** capture a page -> preserve -> verify -> add to a report.
- **Deployment, in order:**
  1. A personal remote instance the owner can log into from anywhere.
  2. Classroom use: the owner teaches OSINT classes and wants to run Cassie on class systems. Two candidate models, to be chosen later: a VM image students import, or one hosted server with an account per student.
  3. Vendor-hosted SaaS is not a goal now, but the design must keep the door open (see design rules below).

### Defaults chosen on the owner's behalf

The owner had no preference on these. They are working defaults and can be changed at any time.

- **Core database:** PostgreSQL only, run as a container. One code path; supports multi-user classes and later hosting.
- **Collection:** the capture browser runs server-side and is streamed to the user's browser. In a VM image this is simply localhost, so classes work the same way.
- **Frontend:** React + TypeScript, one shared design system.
- **Sign-in:** local accounts with MFA first; SSO (OIDC/SAML) added later.
- **App port order:** Scout (capture), Codex (verify) and Workbench (reports) first, then Watchtower, a merged Crawler (Pathfinder + Scanner), Matchbook, and Observatory.
- **Classroom model:** one class server with browser clients. Students need only a browser, so their laptops (any OS or CPU) do not matter. The same server image runs on a cloud VM or on a machine in the room. A per-student install of the same image stays available as a fallback for offline or special cases. The owner said classes could be either laptops or provided machines, so this model avoids depending on either.

### Roles (confirmed by the owner: instructor = tenant admin, students = regular users)

- **Platform operator:** runs the server and creates tenants. Does not browse tenant data.
- **Tenant admin** (the instructor, or an organization's admin): creates and disables accounts, sees all workspaces in the tenant, resets or exports them, reads the audit log.
- **Regular user:** sees only their own workspace; cannot see other users' data or manage users or settings.
- The same model serves classes, customer-hosted deployments and any later hosted offering.
- Role changes follow explicit escalation rules with tests (Lantern let a workspace admin assign OWNER). Admin access to another user's workspace is audit-logged, and users are told it is possible.

### Classroom requirements (proposed)

- Multiple users with an instructor role and a separate workspace per student; the instructor can see all of them.
- Reset or snapshot a class workspace between sessions, and delete student data on request.
- Resource limits per student, because each streamed capture browser uses real memory and CPU. Size the server by the number of concurrent students.
- Controlled outbound traffic. All students would share one egress IP, so plan for a VPN or proxy and for rate limits or blocks from the sites being searched.
- Works on poor networks: low-bandwidth streaming and a clear offline fallback.

### Design rules that keep the SaaS door open

- Tenancy stays in the data model (organizations and workspaces).
- Each deployment is self-contained: config and secrets live outside the code.
- Everything ships as containers.
- A hosted offering would start as one single-tenant instance per customer, before any shared multi-tenancy.

### Still open

- [ ] Typical class size and whether classes are run in person, online, or both (sizes the server and the network plan)
- [ ] Licensing and third-party tool review before redistributing anything
- [ ] Final project name (Cassie is a working name)
- [ ] Customers in government: which kinds (federal, state/local, law enforcement) and whether they would run it in their own environment

## Non-goals (proposed)

- No bootable OS image until the application runs cleanly in containers on Linux.
- No hosted multi-tenant service until the security baseline and legal review are done.
