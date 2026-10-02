#!/usr/bin/env bash
# ctl: the single entry command for working on and running Cassie.
#
# `./ctl check` runs exactly what CI runs. CI calls `./ctl check <target>`
# per job, so the two cannot drift apart.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

COMPOSE_FILE="$ROOT/deploy/compose/compose.dev.yaml"
SECRETS_DIR="$ROOT/var/secrets"
CHECK_TARGETS=(lint types test)

# Load non-secret local settings, if present.
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi
export CASSIE_BIND_ADDR="${CASSIE_BIND_ADDR:-127.0.0.1}"
export CASSIE_COMPOSE_PROJECT="${CASSIE_COMPOSE_PROJECT:-cassie-dev}"

say() { printf '\033[1m==> %s\033[0m\n' "$*" >&2; }
die() { printf 'ctl: %s\n' "$*" >&2; exit 1; }
run() { printf '+ %s\n' "$*" >&2; "$@"; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed (see README.md)"
}

usage() {
  cat <<'EOF'
Usage: ./ctl <command> [args]

Development
  check [target...]  Run the checks CI runs. Targets: lint, types, test.
                     With no target, runs all of them.
  up                 Start the dev stack (deploy/compose/compose.dev.yaml).
  down               Stop the dev stack. Data volumes are kept.
  logs [service...]  Follow dev stack logs.
  psql               Open psql inside the dev Postgres container.
  db-reset [--yes]   Delete the dev database volume and start fresh. Dev only.

Environment
  CASSIE_ENGINE      podman or docker. Default: podman if installed, else docker.
  CASSIE_BIND_ADDR   Address published ports bind to. Default: 127.0.0.1.
EOF
}

# --- checks -----------------------------------------------------------------

setup_deps() {
  need uv
  need pnpm
  say "Installing locked dependencies"
  run uv sync --locked --all-packages
  run pnpm install --frozen-lockfile
}

check_lint() {
  say "Lint: Python"
  run uv run --locked ruff check
  run uv run --locked ruff format --check
  say "Lint: TypeScript"
  run pnpm run lint
}

check_types() {
  say "Types: Python (mypy strict)"
  run uv run --locked mypy
  say "Types: TypeScript"
  run pnpm run typecheck
}

check_test() {
  say "Tests: Python"
  run uv run --locked pytest -m "not integration"
  say "Tests: TypeScript"
  run pnpm run test
}

cmd_check() {
  local targets=("$@")
  if [[ ${#targets[@]} -eq 0 ]]; then
    targets=("${CHECK_TARGETS[@]}")
  fi
  for t in "${targets[@]}"; do
    [[ " ${CHECK_TARGETS[*]} " == *" $t "* ]] || die "unknown check target: $t (known: ${CHECK_TARGETS[*]})"
  done
  setup_deps
  for t in "${targets[@]}"; do
    "check_${t//-/_}"
  done
  say "All checks passed: ${targets[*]}"
}

# --- dev stack ----------------------------------------------------------------

engine() {
  if [[ -n "${CASSIE_ENGINE:-}" ]]; then
    printf '%s' "$CASSIE_ENGINE"
  elif command -v podman >/dev/null 2>&1; then
    printf 'podman'
  elif command -v docker >/dev/null 2>&1; then
    printf 'docker'
  else
    die "podman or docker is required"
  fi
}

compose() {
  local eng
  eng="$(engine)"
  "$eng" compose -f "$COMPOSE_FILE" "$@"
}

ensure_dev_secrets() {
  mkdir -p "$SECRETS_DIR"
  chmod 700 "$SECRETS_DIR"
  local f="$SECRETS_DIR/postgres_password"
  if [[ ! -s "$f" ]]; then
    say "Generating dev Postgres password in var/secrets/"
    (umask 077 && od -An -tx1 -N32 /dev/urandom | tr -d ' \n' >"$f")
  fi
  # The Postgres container runs as uid 70 and reads this as a bind mount.
  # Dev only: the directory itself stays private to you.
  chmod 644 "$f"
}

require_dev() {
  [[ "${CASSIE_ENV:-dev}" == "dev" ]] || die "refusing: CASSIE_ENV=${CASSIE_ENV} (this command is dev only)"
}

cmd_up() {
  ensure_dev_secrets
  run compose up -d --wait
}

cmd_down() { run compose down; }

cmd_logs() { compose logs -f "$@"; }

cmd_psql() { compose exec postgres psql -U cassie -d cassie; }

cmd_db_reset() {
  require_dev
  if [[ "${1:-}" != "--yes" ]]; then
    printf 'This deletes the dev database volume for project %s. Type "reset" to continue: ' \
      "$CASSIE_COMPOSE_PROJECT" >&2
    local answer
    read -r answer
    [[ "$answer" == "reset" ]] || die "aborted"
  fi
  run compose down -v
  cmd_up
}

# --- main ---------------------------------------------------------------------

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    check) cmd_check "$@" ;;
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    logs) cmd_logs "$@" ;;
    psql) cmd_psql "$@" ;;
    db-reset) cmd_db_reset "$@" ;;
    help | -h | --help) usage ;;
    *) usage >&2; die "unknown command: $cmd" ;;
  esac
}

main "$@"
