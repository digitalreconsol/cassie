#!/usr/bin/env bash
# Prove `./ctl check` passes on a clean checkout in a fresh Linux container
# that has only Node, uv and pnpm. Tests committed content only: the tree is
# taken with `git archive`, so local changes and ignored files are left out.
#
# Usage: scripts/verify-clean-clone.sh [git-ref]   (default: HEAD)

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-HEAD}"
if [[ -n "${CASSIE_ENGINE:-}" ]]; then
  ENGINE="$CASSIE_ENGINE"
elif command -v podman >/dev/null 2>&1; then
  ENGINE=podman
else
  ENGINE=docker
fi

# node:24-bookworm-slim and ghcr.io/astral-sh/uv:0.12.17, pinned by digest.
NODE_IMAGE="docker.io/library/node@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6"
UV_IMAGE="ghcr.io/astral-sh/uv@sha256:10787c682e4184e4f290de1171fd4703dc63de99221f10fe1c99002ce7fa9acc"
PNPM_VERSION="$(sed -n 's/.*"packageManager": "pnpm@\([^"]*\)".*/\1/p' "$ROOT/package.json")"
TAG="cassie-verify-clean:local"

"$ENGINE" build -q -t "$TAG" - <<EOF
FROM $UV_IMAGE AS uv
FROM $NODE_IMAGE
COPY --from=uv /uv /uvx /usr/local/bin/
RUN npm install -g --silent pnpm@$PNPM_VERSION
RUN useradd -m dev
USER dev
WORKDIR /home/dev/cassie
EOF

git -C "$ROOT" archive --format=tar "$REF" \
  | "$ENGINE" run --rm -i "$TAG" bash -euo pipefail -c 'tar -x && ./ctl check'
