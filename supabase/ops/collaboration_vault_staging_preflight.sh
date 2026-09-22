#!/bin/sh

set -eu

production_project_ref="xxqdytdbpiqjilhutvhz"
approved_staging_ref="bvtuyzhyospqxvpzcrmv"
required_commit="0cdaf4cbf43e54f9808d397dc4552ae4a2d1907d"

usage() {
  echo "Usage: $0 <expected-staging-project-ref>"
  echo "Performs read-only rollout checks. It never links, migrates, deploys, or sets secrets."
}

fail() {
  echo "PRECHECK FAILED: $1" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

expected_staging_ref="$1"
case "$expected_staging_ref" in
  *[!a-z0-9]*|'') fail "The staging project ref must contain only lowercase letters and digits." ;;
esac

if [ "${#expected_staging_ref}" -ne 20 ]; then
  fail "The staging project ref must be exactly 20 characters."
fi

if [ "$expected_staging_ref" = "$production_project_ref" ]; then
  fail "The supplied project is Miloom production. This preflight is staging-only."
fi

if [ "$expected_staging_ref" != "$approved_staging_ref" ]; then
  fail "The supplied project is not the approved Miloom Staging project."
fi

for command_name in git jq supabase deno; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command is unavailable: $command_name"
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "Run this inside the Miloom repository."
cd "$repo_root"

linked_ref_file="supabase/.temp/project-ref"
linked_project_file="supabase/.temp/linked-project.json"
[ -f "$linked_ref_file" ] || fail "Supabase is not linked. Link the confirmed staging project first."
[ -f "$linked_project_file" ] || fail "Supabase linked-project metadata is unavailable."

linked_ref="$(tr -d '\r\n' < "$linked_ref_file")"
[ "$linked_ref" = "$expected_staging_ref" ] || fail "The linked project does not match the explicitly supplied staging project ref."
[ "$linked_ref" != "$production_project_ref" ] || fail "The linked project is Miloom production."

linked_name="$(jq -r '.name // empty' "$linked_project_file")"
case "$(printf '%s' "$linked_name" | tr '[:upper:]' '[:lower:]')" in
  *staging*|*stage*|*development*|*sandbox*|*test*) ;;
  *) fail "Linked project name '$linked_name' does not clearly identify a staging environment." ;;
esac

git merge-base --is-ancestor "$required_commit" HEAD || fail "HEAD does not contain the verified Phase 5 commit $required_commit."

release_paths="
miloom-web/.well-known/apple-app-site-association
miloom-web/invite.html
miloom-web/vercel.json
supabase/functions/approve-vault-device
supabase/functions/_shared/share_email.ts
supabase/functions/_shared/share_email_test.ts
supabase/functions/send-share-email
supabase/migrations/202609210001_secure_active_sessions.sql
supabase/migrations/202609210002_canonical_resource_access.sql
supabase/migrations/202609210003_invitation_lifecycle.sql
supabase/migrations/202609210004_vault_key_foundation.sql
supabase/migrations/202609210005_vault_device_approval_and_recovery.sql
supabase/migrations/202609210006_vault_rotation_and_device_revocation.sql
supabase/migrations/202609220001_expand_resource_invitation_statuses.sql
supabase/migrations/202609220002_harden_legacy_resource_access.sql
supabase/migrations/202609220003_restore_auth_user_triggers.sql
supabase/migrations/202609220004_disable_automatic_invitation_acceptance.sql
supabase/tests/canonical_resource_access_contracts.sql
supabase/tests/auth_user_trigger_contracts.sql
supabase/tests/active_sessions_contracts.sql
supabase/tests/invitation_lifecycle_contracts.sql
supabase/tests/vault_key_foundation_contracts.sql
supabase/tests/vault_phase4_contracts.sql
supabase/tests/vault_phase5_contracts.sql
"

for required_path in $release_paths; do
  [ -e "$required_path" ] || fail "Required rollout artifact is missing: $required_path"
done

dirty_paths="$(git status --porcelain --untracked-files=all -- $release_paths)"
[ -z "$dirty_paths" ] || fail "Collaboration/vault rollout artifacts contain uncommitted changes."

jq -e '
  .applinks.details[]
  | select(.appID == "WYYJ6FGYRP.com.vibing.miloom")
  | (.paths | index("/invite")) != null
' miloom-web/.well-known/apple-app-site-association >/dev/null \
  || fail "The Apple association file does not authorize the Miloom invitation path."

if grep -Eiq '<script([[:space:]>])' miloom-web/invite.html; then
  fail "The invitation fallback must remain script-free."
fi

echo "PRECHECK PASSED"
echo "Linked staging project: $linked_name ($linked_ref)"
echo "Verified Phase 5 baseline: $required_commit"
echo "No deployment or external mutation was performed."
