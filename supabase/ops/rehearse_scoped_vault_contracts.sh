#!/bin/sh
# Local-only scoped-vault contracts. No hosted credentials or network required.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"
scratch_dir=$(mktemp -d /private/tmp/miloom-scoped-vault.XXXXXX)
started=false
cleanup() {
  if [ "$started" = true ]; then pg_ctl -D "$scratch_dir/pg" stop -m fast >/dev/null 2>&1 || true; fi
  # Retain logs/database for failure diagnosis; no running server remains.
  printf 'Local evidence directory: %s\n' "$scratch_dir"
}
trap cleanup EXIT
mkdir "$scratch_dir/socket"
initdb -D "$scratch_dir/pg" -A trust --no-instructions >"$scratch_dir/init.log"
pg_ctl -w -D "$scratch_dir/pg" -o "-k $scratch_dir/socket -p 5432 -c listen_addresses=''" -l "$scratch_dir/server.log" start >/dev/null
started=true
psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -d postgres -c 'CREATE ROLE service_role NOLOGIN BYPASSRLS'
run_sql() { psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -d "$case_db" -f "$1" >>"$scratch_dir/$case_db.log" 2>&1; }
if [ "$#" = 0 ]; then set -- foundation owner_stage device_grant owner_rewrap rotation status scoped_update; fi
for scenario in "$@"; do
  case "$scenario" in foundation|owner_stage|device_grant|owner_rewrap|rotation|status|scoped_update) ;; *) echo 'Unknown scenario' >&2; exit 1 ;; esac
  case_db="vault_$scenario"
  createdb -h "$scratch_dir/socket" "$case_db"
  run_sql supabase/tests/delegated_scope_fixture.sql
  for number in $(seq 9 21); do
    if [ "$number" = 12 ]; then run_sql supabase/tests/resource_secret_foundation_fixture.sql; fi
    prefix=$(printf '20260922%04d' "$number")
    set -- supabase/migrations/"$prefix"_*.sql
    [ "$#" = 1 ] && [ -f "$1" ]
    run_sql "$1"
  done
  case "$scenario" in
    foundation) run_sql supabase/tests/resource_secret_foundation_assertions.sql ;;
    owner_stage) run_sql supabase/tests/owner_resource_secret_staging_assertions.sql ;;
    device_grant) run_sql supabase/tests/resource_secret_device_grant_assertions.sql ;;
    owner_rewrap) run_sql supabase/tests/resource_secret_owner_rewrap_assertions.sql ;;
    rotation)
      run_sql supabase/tests/resource_secret_source_revision_assertions.sql
      run_sql supabase/tests/resource_secret_cutover_closed_assertions.sql
      run_sql supabase/tests/resource_secret_rotation_assertions.sql
      run_sql supabase/tests/resource_secret_lifecycle_assertions.sql
      run_sql supabase/tests/resource_secret_containment_rollback_assertions.sql ;;
    status) run_sql supabase/tests/resource_secret_access_status_assertions.sql ;;
    scoped_update) run_sql supabase/tests/resource_secret_scoped_update_assertions.sql ;;
  esac
  printf 'PASS scoped-vault scenario: %s\n' "$scenario"
done
printf 'Selected SQL scenarios passed. Synthetic ciphertext is not native device/decryption acceptance.\n'
