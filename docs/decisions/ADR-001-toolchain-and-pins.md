# ADR-001: Toolchain versions and how they are pinned

Status: Accepted, 2026-10-02 (foundation phase 1)

## Context

The foundation prompt asks for Python 3.13 with a uv workspace, strict TypeScript in a pnpm workspace, ESLint, Vitest, and everything pinned. At the time of writing the newest releases do not all fit together: typescript-eslint 8.71 supports TypeScript `<6.1`, and eslint-plugin-react 7.37 supports ESLint up to 9. TypeScript 7 and ESLint 10 are out.

## Decision

- **Python 3.13** (`requires-python = ">=3.13,<3.14"`, `.python-version`). One uv workspace (`libs/py/*`, `core`) with one `uv.lock`. Packages use the `src/` layout and the `uv_build` backend. pytest runs with `--import-mode=importlib` so every package can keep a plain `tests/` directory.
- **TypeScript 6.0** and **ESLint 9**, the newest versions the lint plugins support. We do not override peer ranges. Move to TypeScript 7 and ESLint 10 when typescript-eslint and eslint-plugin-react support them.
- **pnpm 12**, pinned in `packageManager`. One `pnpm-lock.yaml`; installs use `--frozen-lockfile`.
- Pinning: lockfiles for all language dependencies; container images by digest (the tag is kept in a comment); GitHub Actions and pre-commit hook repos by commit SHA.
- The React version for eslint-plugin-react is set explicitly in `eslint.config.js`, because `detect` cannot see React from the repo root under pnpm's isolated layout.

## Consequences

- Dependency update tooling (phase 2) must respect the TypeScript and ESLint ceilings until the plugins catch up; a forced bump will show up as a peer-dependency failure.
- Pins must be refreshed deliberately. A stale pin is a visible diff, not a silent change.
