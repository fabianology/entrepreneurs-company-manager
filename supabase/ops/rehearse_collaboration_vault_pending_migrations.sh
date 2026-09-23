#!/bin/sh

# Local-only migration-order rehearsal. Creates an isolated PostgreSQL cluster
# with Unix-socket access and synthetic data, then removes it on exit.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

for dependency in initdb pg_ctl psql mktemp seq; do
  command -v "$dependency" >/dev/null 2>&1 || {
    printf 'Missing local dependency: %s\n' "$dependency" >&2
    exit 1
  }
done

scratch_dir=$(mktemp -d /private/tmp/miloom-collab-rehearsal.XXXXXX)
mkdir "$scratch_dir/socket"
cluster_started=false

cleanup() {
  if [ "$cluster_started" = true ]; then
    pg_ctl -D "$scratch_dir/pg" stop -m immediate >/dev/null 2>&1 || true
  fi
  case "$scratch_dir" in
    /private/tmp/miloom-collab-rehearsal.*)
      rm -r -- "$scratch_dir"
      ;;
  esac
}
trap cleanup EXIT

initdb -D "$scratch_dir/pg" -A trust --no-instructions >/dev/null
cluster_started=true
pg_ctl -w -D "$scratch_dir/pg" \
  -o "-k $scratch_dir/socket -p 5432 -c listen_addresses=''" \
  -l "$scratch_dir/postgres.log" start >/dev/null

run_sql() {
  psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -p 5432 \
    -d postgres -f "$1"
}

run_sql supabase/tests/delegated_scope_fixture.sql
psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -p 5432 \
  -d postgres -c 'CREATE ROLE service_role NOLOGIN BYPASSRLS'

for migration_number in $(seq 9 33); do
  case "$migration_number" in
    12) run_sql supabase/tests/resource_secret_foundation_fixture.sql ;;
    22) run_sql supabase/tests/document_storage_exact_read_fixture.sql ;;
    24) run_sql supabase/tests/document_orphan_cleanup_fixture.sql ;;
    26) run_sql supabase/tests/document_upload_reservation_fixture.sql ;;
    30) run_sql supabase/tests/loan_payment_atomic_fixture.sql ;;
    32) run_sql supabase/tests/institution_collection_constraint_fixture.sql ;;
  esac

  migration_prefix=$(printf '20260922%04d' "$migration_number")
  set -- supabase/migrations/"$migration_prefix"_*.sql
  if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf 'Expected one migration for %s\n' "$migration_prefix" >&2
    exit 1
  fi
  printf 'Applying %s\n' "${1##*/}"
  run_sql "$1"
done

run_sql supabase/tests/loan_payment_atomic_assertions.sql
run_sql supabase/tests/institution_collection_constraint_assertions.sql
printf 'Local migration-order rehearsal, loan and institution-collection contracts passed (009–033).\n'
printf 'No hosted database was contacted; this does not verify live Storage or behavior.\n'
