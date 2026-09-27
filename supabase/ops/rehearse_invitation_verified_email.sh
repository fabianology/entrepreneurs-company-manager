#!/bin/sh
# Isolated socket-only PostgreSQL with synthetic Auth/document fields.
set -eu
cd "$(dirname "$0")/../.."
scratch_dir=$(mktemp -d /private/tmp/miloom-invite-verification.XXXXXX)
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
run_sql supabase/tests/delegated_scope_fixture.sql
run_sql supabase/tests/invitation_verified_email_fixture.sql
for number in 9 10 11; do
 prefix=$(printf '20260922%04d' "$number")
 set -- supabase/migrations/"$prefix"_*.sql
 [ "$#" = 1 ] && [ -f "$1" ]
 run_sql "$1"
done
run_sql supabase/migrations/202609210003_invitation_lifecycle.sql
run_sql supabase/migrations/202609270003_invitation_verified_email_guard.sql
run_sql supabase/tests/invitation_verified_email_assertions.sql
printf 'PASS invitation verified-email contract\n'
