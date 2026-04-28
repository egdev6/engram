#!/usr/bin/env bash
# Temporary/manual rescue helper for legacy Engram Cloud upgrade data.
#
# This script patches one legacy `sync_mutations` row whose `session` upsert
# payload is missing `directory`, producing the doctor error:
#   session payload directory is required and cannot be inferred from local state (seq=N entity=session op=upsert)
#
# It is intentionally conservative: dry-run is the default, `--apply` creates a
# timestamped SQLite backup, and it never touches `last_acked_seq` or deletes
# sync mutations. Prefer the built-in `engram cloud upgrade repair` flow when it
# can infer the directory on its own; use this only for the manual rescue case.

set -eu

usage() {
  cat <<'USAGE'
Usage: repair-missing-session-directory.sh [--apply] [--seq N] PROJECT [DIRECTORY]

Safely patch a legacy session sync mutation payload to add `directory`.

Arguments:
  PROJECT     Required Engram project name passed to cloud upgrade doctor.
  DIRECTORY   Optional session directory. Defaults to git root, then pwd.

Flags:
  --apply     Write changes. Default is dry-run and does not modify the DB.
  --seq N     Use a known sync_mutations.seq instead of parsing doctor output.
  -h, --help  Show this help.

Environment:
  ENGRAM_DB   SQLite DB path. Defaults to ~/.engram/engram.db.

Next flow after a successful apply:
  engram cloud upgrade doctor --project PROJECT
  engram cloud upgrade repair --project PROJECT --dry-run
  engram cloud upgrade repair --project PROJECT --apply
  engram sync --cloud --project PROJECT
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

sql_escape() {
  # SQLite string literal escaping: single quote becomes two single quotes.
  # Usage: printf "'%s'" "$(sql_escape "$value")"
  printf "%s" "$1" | sed "s/'/''/g"
}

abs_path_if_possible() {
  case "$1" in
    /* | [A-Za-z]:/*) printf '%s\n' "$1" ;;
    *)
      if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null || printf '%s/%s\n' "$(pwd)" "$1"
      else
        printf '%s/%s\n' "$(pwd)" "$1"
      fi
      ;;
  esac
}

is_absoluteish_directory() {
  case "$1" in
    /* | [A-Za-z]:/*) return 0 ;;
    *) return 1 ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

db_path() {
  if [ "${ENGRAM_DB:-}" ]; then
    printf '%s\n' "$ENGRAM_DB"
  else
    printf '%s\n' "$HOME/.engram/engram.db"
  fi
}

sqlite_scalar() {
  sqlite3 -batch -noheader "$DB" "$1"
}

sqlite_box() {
  sqlite3 -batch -box "$DB" "$1"
}

have_table() {
  [ "$(sqlite_scalar "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$(sql_escape "$1")';")" = "1" ]
}

have_column() {
  [ "$(sqlite_scalar "SELECT COUNT(*) FROM pragma_table_info('$(sql_escape "$1")') WHERE name = '$(sql_escape "$2")';")" = "1" ]
}

parse_seq_from_doctor() {
  output_file=$1
  if ! engram cloud upgrade doctor --project "$PROJECT" >"$output_file" 2>&1; then
    : # doctor is expected to fail for the legacy mutation this helper repairs.
  fi
  parsed=$(sed -n 's/.*seq=\([0-9][0-9]*\) entity=session op=upsert.*/\1/p' "$output_file" | sed -n '1p')
  [ "$parsed" ] || return 1
  printf '%s\n' "$parsed"
}

APPLY=0
SEQ=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --seq)
      [ "$#" -ge 2 ] || die "--seq requires a numeric value"
      SEQ=$2
      shift 2
      ;;
    --seq=*)
      SEQ=${1#--seq=}
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*)
      die "unknown flag: $1"
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -ge 1 ] || { usage >&2; die "PROJECT is required"; }
[ "$#" -le 2 ] || die "too many arguments"

PROJECT=$1
DIRECTORY_ARG=${2:-}
[ "$PROJECT" ] || die "PROJECT must not be empty"

case "$SEQ" in
  "" | *[!0-9]*) [ "$SEQ" = "" ] || die "--seq must be a positive integer" ;;
esac

require_cmd sqlite3

if [ "$DIRECTORY_ARG" ]; then
  DIRECTORY=$(abs_path_if_possible "$DIRECTORY_ARG")
elif command -v git >/dev/null 2>&1 && git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  DIRECTORY=$git_root
else
  DIRECTORY=$(pwd)
fi

is_absoluteish_directory "$DIRECTORY" || die "directory must be absolute-ish (/..., /c/..., or C:/...): $DIRECTORY"

DB=$(db_path)
[ -f "$DB" ] || die "SQLite DB not found: $DB (override with ENGRAM_DB=/path/to/engram.db)"

have_table sync_mutations || die "sync_mutations table not found in DB: $DB"

if [ ! "$SEQ" ]; then
  require_cmd engram
  tmp=${TMPDIR:-/tmp}/engram-doctor-output.$$.txt
  trap 'rm -f "$tmp"' EXIT HUP INT TERM
  if ! SEQ=$(parse_seq_from_doctor "$tmp"); then
    cat "$tmp" >&2 || true
    die "could not parse 'seq=N entity=session op=upsert' from doctor output; rerun with --seq N"
  fi
fi

PROJECT_SQL=$(sql_escape "$PROJECT")
DIRECTORY_SQL=$(sql_escape "$DIRECTORY")
SEQ_SQL=$(sql_escape "$SEQ")

row_count=$(sqlite_scalar "SELECT COUNT(*) FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")
[ "$row_count" = "1" ] || die "expected exactly one sync_mutations row for seq=$SEQ entity=session op=upsert, found $row_count"

payload_project=$(sqlite_scalar "SELECT ifnull(json_extract(payload, '$.project'), '') FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")
[ "$payload_project" = "$PROJECT" ] || die "payload project mismatch for seq=$SEQ: got '$payload_project', want '$PROJECT'"

existing_directory=$(sqlite_scalar "SELECT ifnull(json_extract(payload, '$.directory'), '') FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")
[ ! "$existing_directory" ] || die "payload already has directory for seq=$SEQ: $existing_directory"

session_id=$(sqlite_scalar "SELECT coalesce(nullif(json_extract(payload, '$.id'), ''), nullif(entity_key, '')) FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")
[ "$session_id" ] || die "payload id/entity_key is required for seq=$SEQ"
SESSION_ID_SQL=$(sql_escape "$session_id")

current_payload=$(sqlite_scalar "SELECT payload FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")
patched_payload=$(sqlite_scalar "SELECT json_set(payload, '$.directory', '$DIRECTORY_SQL') FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")

info "Preview"
info "-------"
info "DB path: $DB"
info "Project: $PROJECT"
info "Seq: $SEQ"
info "Session id: $session_id"
info "Directory: $DIRECTORY"
info ""
info "Current payload:"
printf '%s\n' "$current_payload"
info ""
info "Patched payload:"
printf '%s\n' "$patched_payload"
info ""
info "Matching mutation row:"
if have_column sync_mutations project; then
  sqlite_box "SELECT seq, entity, entity_key, op, ifnull(project, '') AS row_project FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER);" || true
else
  sqlite_box "SELECT seq, entity, entity_key, op FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER);" || true
fi

if [ "$APPLY" -ne 1 ]; then
  info ""
  info "Dry-run only: no database changes were made. Re-run with --apply to write."
else
  backup="$DB.repair-missing-session-directory.$(date +%Y%m%d%H%M%S).bak"
  cp "$DB" "$backup"
  info ""
  info "Backup created: $backup"

  sqlite3 -batch "$DB" "BEGIN;
UPDATE sync_mutations
SET payload = json_set(payload, '$.directory', '$DIRECTORY_SQL')
WHERE seq = CAST('$SEQ_SQL' AS INTEGER)
  AND entity = 'session'
  AND op = 'upsert'
  AND ifnull(json_extract(payload, '$.project'), '') = '$PROJECT_SQL'
  AND ifnull(json_extract(payload, '$.directory'), '') = '';
COMMIT;"

  if have_table sessions; then
    sqlite3 -batch "$DB" "UPDATE sessions
SET directory = '$DIRECTORY_SQL'
WHERE id = '$SESSION_ID_SQL'
  AND ifnull(directory, '') = '';"
  fi

  verified_directory=$(sqlite_scalar "SELECT ifnull(json_extract(payload, '$.directory'), '') FROM sync_mutations WHERE seq = CAST('$SEQ_SQL' AS INTEGER) AND entity = 'session' AND op = 'upsert';")
  [ "$verified_directory" = "$DIRECTORY" ] || die "verification failed: payload directory is '$verified_directory', want '$DIRECTORY'"
  info "Apply complete: payload directory verified."
fi

info ""
info "Next commands:"
info "  engram cloud upgrade doctor --project $PROJECT"
info "  engram cloud upgrade repair --project $PROJECT --dry-run"
info "  engram cloud upgrade repair --project $PROJECT --apply"
info "  engram sync --cloud --project $PROJECT"
