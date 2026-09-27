#!/bin/sh
# Local synthetic database only. Keeps evidence; always stops its socket-only server.
set -eu
cd "$(dirname "$0")/../.."
case "${1:-fixed}" in fixed|vulnerable) mode=${1:-fixed} ;; *) exit 2 ;; esac
scratch_dir=$(mktemp -d /private/tmp/miloom-document-scope.XXXXXX)
started=false
cleanup() {
  if [ "$started" = true ]; then pg_ctl -D "$scratch_dir/pg" stop -m fast >/dev/null 2>&1 || true; fi
  printf 'Evidence: %s\n' "$scratch_dir"
}
trap cleanup EXIT
mkdir "$scratch_dir/socket"
initdb -D "$scratch_dir/pg" -A trust --no-instructions >"$scratch_dir/init.log"
pg_ctl -w -D "$scratch_dir/pg" -o "-k $scratch_dir/socket -p 5432 -c listen_addresses=''" -l "$scratch_dir/server.log" start >/dev/null
started=true
run_sql() { psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -d postgres -f "$1" >>"$scratch_dir/contracts.log" 2>&1; }
psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -d postgres -c 'CREATE ROLE service_role NOLOGIN BYPASSRLS'
run_sql supabase/tests/delegated_scope_fixture.sql
for number in $(seq 9 33); do
  case "$number" in
    12) run_sql supabase/tests/resource_secret_foundation_fixture.sql ;;
    22) run_sql supabase/tests/document_storage_exact_read_fixture.sql ;;
    24) run_sql supabase/tests/document_orphan_cleanup_fixture.sql ;;
    26) run_sql supabase/tests/document_upload_reservation_fixture.sql ;;
    30) run_sql supabase/tests/loan_payment_atomic_fixture.sql ;;
    32) run_sql supabase/tests/institution_collection_constraint_fixture.sql ;;
  esac
  prefix=$(printf '20260922%04d' "$number")
  set -- supabase/migrations/"$prefix"_*.sql
  [ "$#" = 1 ] && [ -f "$1" ]
  run_sql "$1"
done
run_sql supabase/migrations/202609270001_editor_resource_scope_guard.sql
if [ "$mode" = fixed ]; then run_sql supabase/migrations/202609270002_document_identity_scope_guard.sql; fi
psql -X -q -v ON_ERROR_STOP=1 -v review_mode="$mode" -h "$scratch_dir/socket" -d postgres -f supabase/tests/document_identity_scope_assertions.sql >>"$scratch_dir/contracts.log" 2>&1
if [ "$mode" = fixed ]; then
  for contract in document_upload_reservation document_file_removal document_storage_write_boundary document_legacy_url_cleanup; do
    # Each existing contract mutates fixtures; use its own transaction rollback.
    psql -X -q -v ON_ERROR_STOP=1 -h "$scratch_dir/socket" -d postgres -c 'BEGIN' -f "supabase/tests/${contract}_assertions.sql" -c 'ROLLBACK' >>"$scratch_dir/contracts.log" 2>&1
  done
fi
printf 'PASS document scope %s and selected compatible document contracts\n' "$mode"
