// Disposable, staging-only hosted document-file acceptance smoke. Requires
// MILOOM_STAGING_SMOKE, MILOOM_STAGING_CRON_SECRET, SUPABASE_URL,
// SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY. Never print the keys,
// passwords, or signed tokens.
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const ref = "bvtuyzhyospqxvpzcrmv";
const url = `https://${ref}.supabase.co`;
if (Deno.env.get("MILOOM_STAGING_SMOKE") !== ref || Deno.env.get("SUPABASE_URL") !== url) {
  throw new Error("This smoke test is restricted to Miloom Staging");
}
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const cronSecret = Deno.env.get("MILOOM_STAGING_CRON_SECRET");
if (!anonKey || !serviceKey || !cronSecret) throw new Error("Missing staging credentials");

const service = createClient(url, serviceKey, { auth: { persistSession: false } });
const clients: Record<string, SupabaseClient> = {};
const createdUsers: string[] = [];
const fixture = crypto.randomUUID();
const companyId = crypto.randomUUID();
const documentId = crypto.randomUUID();
const uploadedPaths: string[] = [];
let mainError: Error | undefined;
let workerCompleted = false;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function requireData<T>(result: { data: T | null; error: { message: string } | null }, label: string): T {
  if (result.error || result.data === null) {
    throw new Error(`${label}: ${result.error?.message ?? "no data"}`);
  }
  return result.data;
}

async function verifyHostedObject(ownerId: string, path: string, byteCount: number) {
  assert(/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.txt$/.test(path), "Unexpected signed upload path");
  const sql = `SELECT owner_id IS NULL AS owner_id_null,
    owner_id = '${ownerId}' AS owner_id_matches,
    split_part(name, '/', 1) = '${ownerId}' AS owner_folder_matches,
    (metadata ->> 'size')::bigint = ${byteCount} AS size_matches
    FROM storage.objects WHERE bucket_id = 'CompanyDocuments' AND name = '${path}'`;
  const queried = await new Deno.Command("supabase", {
    args: ["db", "query", "--linked", "--project-ref", ref, sql],
    stdout: "piped", stderr: "piped",
  }).output();
  assert(queried.success, "Staging object metadata query failed");
  const result = JSON.parse(new TextDecoder().decode(queried.stdout)) as {
    rows?: Array<Record<string, boolean>>;
  };
  assert(result.rows?.length === 1, "Signed upload has no exact Storage metadata row");
  const row = result.rows[0];
  assert(row.owner_folder_matches === true && row.size_matches === true,
    "Signed upload owner folder or stored byte count was wrong");
  assert(row.owner_id_null === true || row.owner_id_matches === true,
    "Signed upload Storage owner_id belongs to another user");
  return row.owner_id_null ? "null (owner folder verified)" : "owner account";
}

async function createSignedInUser(role: "owner" | "editor" | "viewer") {
  const email = `miloom-staging-doc-${role}-${fixture}@example.com`;
  const password = `M!${crypto.randomUUID()}`;
  const created = await service.auth.admin.createUser({ email, password, email_confirm: true });
  if (created.error || !created.data.user) {
    throw new Error(`create ${role}: ${created.error?.message ?? "no user"}`);
  }
  createdUsers.push(created.data.user.id);
  const client = createClient(url, anonKey!, { auth: { persistSession: false } });
  const signedIn = await client.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session) {
    throw new Error(`sign in ${role}: ${signedIn.error?.message ?? "no session"}`);
  }
  clients[role] = client;
  return { id: created.data.user.id, token: signedIn.data.session.access_token };
}

async function removeFixture() {
  const failures: string[] = [];
  const owner = clients.owner;
  const document = await service.from("company_documents")
    .select("url").eq("id", documentId).maybeSingle();
  if (document.error) failures.push(`inspect document: ${document.error.message}`);
  if (document.data && owner) {
    const deleted = await owner.rpc("miloom_delete_document_with_file", {
      p_document_id: documentId,
      p_expected_url: document.data.url,
    });
    if (deleted.error) failures.push(`delete document: ${deleted.error.message}`);
  } else if (document.data) {
    const deleted = await service.from("company_documents").delete().eq("id", documentId);
    if (deleted.error) failures.push(`delete empty document: ${deleted.error.message}`);
  }
  const shares = await service.from("resource_shares").delete()
    .in("resource_id", [companyId, documentId]);
  if (shares.error) failures.push(`delete shares: ${shares.error.message}`);
  const company = await service.from("companies").delete().eq("id", companyId);
  if (company.error) failures.push(`delete company: ${company.error.message}`);
  if (uploadedPaths.length && !workerCompleted) {
    try {
      const worker = await fetch(`${url}/functions/v1/cleanup-document-files`, {
        method: "POST",
        headers: { "x-cron-secret": cronSecret!, "Content-Type": "application/json" },
        body: "{}",
      });
      if (!worker.ok) failures.push(`retry cleanup worker: HTTP ${worker.status}`);
    } catch (error) {
      failures.push(`retry cleanup worker: ${String(error)}`);
    }
  }
  if (uploadedPaths.length) {
    const removed = await service.storage.from("CompanyDocuments").remove(uploadedPaths);
    if (removed.error) failures.push(`remove test object: ${removed.error.message}`);
    const pending = await service.rpc("miloom_pending_document_file_cleanup", { p_limit: 100 });
    if (pending.error || !Array.isArray(pending.data)
      || pending.data.some((row: { path: string }) => uploadedPaths.includes(row.path))) {
      failures.push("test path remains in cleanup queue");
    }
  }
  for (const id of createdUsers) {
    const removed = await service.auth.admin.deleteUser(id);
    if (removed.error) failures.push(`remove test user: ${removed.error.message}`);
  }
  return failures;
}

try {
  const owner = await createSignedInUser("owner");
  const editor = await createSignedInUser("editor");
  const viewer = await createSignedInUser("viewer");

  requireData(await service.from("companies").insert({
    id: companyId, user_id: owner.id, name: "Miloom Staging Document Smoke",
  }).select("id").single(), "create company");
  requireData(await service.from("company_documents").insert({
    id: documentId, user_id: owner.id, company_id: companyId,
    name: "Disposable document", visibility: "entity",
  }).select("id").single(), "create document");
  requireData(await service.from("resource_shares").insert([
    { resource_id: documentId, resource_type: "document", user_id: editor.id, role: "Editor" },
    { resource_id: companyId, resource_type: "company", user_id: viewer.id, role: "Viewer" },
  ]).select("id"), "create exact Editor and entity Viewer shares");

  const editorStatus = requireData(await clients.editor.rpc("miloom_document_upload_status", {
    p_document_id: documentId,
  }), "Editor upload status") as { can_upload?: boolean };
  const viewerStatus = requireData(await clients.viewer.rpc("miloom_document_upload_status", {
    p_document_id: documentId,
  }), "Viewer upload status") as { can_upload?: boolean };
  assert(editorStatus.can_upload === true, "Exact Editor could not upload");
  assert(viewerStatus.can_upload === false, "Viewer could upload");

  const bytes = new TextEncoder().encode(`MILOOM staging document smoke ${fixture}`);
  const issued = await fetch(`${url}/functions/v1/prepare-document-upload`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${editor.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      document_id: documentId, expected_url: null,
      extension: "txt", byte_count: bytes.length,
    }),
  });
  assert(issued.ok, `Editor upload issuer returned HTTP ${issued.status}`);
  const reservation = await issued.json() as {
    reservation_id?: string; path?: string; token?: string;
  };
  assert(reservation.reservation_id && reservation.path && reservation.token,
    "Upload issuer omitted reservation details");
  assert(reservation.path.startsWith(`${owner.id}/`), "Upload path escaped owner folder");
  uploadedPaths.push(reservation.path);

  const uploaded = await clients.editor.storage.from("CompanyDocuments")
    .uploadToSignedUrl(reservation.path, reservation.token,
      new Blob([bytes], { type: "text/plain" }), { contentType: "text/plain" });
  assert(!uploaded.error, `Signed upload failed: ${uploaded.error?.message}`);
  const storageOwner = await verifyHostedObject(owner.id, reservation.path, bytes.length);
  requireData(await clients.editor.rpc("miloom_finalize_document_upload", {
    p_reservation_id: reservation.reservation_id,
  }), "finalize signed upload");

  const stored = requireData(await service.from("company_documents")
    .select("url").eq("id", documentId).single(), "read stored document") as { url: string };
  assert(stored.url === reservation.path, "Finalized path did not attach to document");
  for (const role of ["owner", "editor", "viewer"] as const) {
    const signed = await clients[role].storage.from("CompanyDocuments")
      .createSignedUrl(reservation.path, 60);
    assert(!signed.error && signed.data?.signedUrl,
      `${role} could not read the shared document`);
    if (role === "editor") {
      const download = await fetch(signed.data.signedUrl);
      assert(download.ok && await download.text() === new TextDecoder().decode(bytes),
        "Signed document download did not match uploaded bytes");
    }
  }

  const directPath = `${owner.id}/${crypto.randomUUID()}.txt`;
  const direct = await clients.editor.storage.from("CompanyDocuments")
    .upload(directPath, bytes, { contentType: "text/plain" });
  if (!direct.error) {
    await service.storage.from("CompanyDocuments").remove([directPath]);
    throw new Error("Editor directly uploaded into owner's folder");
  }

  const replacementBytes = new TextEncoder().encode(`MILOOM replacement ${fixture}`);
  const replacementIssued = await fetch(`${url}/functions/v1/prepare-document-upload`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${editor.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      document_id: documentId, expected_url: reservation.path,
      extension: "txt", byte_count: replacementBytes.length,
    }),
  });
  assert(replacementIssued.ok, `Replacement issuer returned HTTP ${replacementIssued.status}`);
  const replacement = await replacementIssued.json() as {
    reservation_id?: string; path?: string; token?: string;
  };
  assert(replacement.reservation_id && replacement.path && replacement.token,
    "Replacement issuer omitted reservation details");
  assert(replacement.path !== reservation.path && replacement.path.startsWith(`${owner.id}/`),
    "Replacement reused old path or escaped owner folder");
  uploadedPaths.push(replacement.path);
  const replacedUpload = await clients.editor.storage.from("CompanyDocuments")
    .uploadToSignedUrl(replacement.path, replacement.token,
      new Blob([replacementBytes], { type: "text/plain" }), { contentType: "text/plain" });
  assert(!replacedUpload.error, `Signed replacement failed: ${replacedUpload.error?.message}`);
  await verifyHostedObject(owner.id, replacement.path, replacementBytes.length);
  requireData(await clients.editor.rpc("miloom_finalize_document_upload", {
    p_reservation_id: replacement.reservation_id,
  }), "finalize replacement");
  const attachedReplacement = requireData(await service.from("company_documents")
    .select("url").eq("id", documentId).single(), "read replacement") as { url: string };
  assert(attachedReplacement.url === replacement.path, "Replacement was not attached");
  const oldQueued = requireData(await service.rpc("miloom_pending_document_file_cleanup", {
    p_limit: 100,
  }), "read replacement cleanup queue") as Array<{ path: string }>;
  assert(oldQueued.some((row) => row.path === reservation.path),
    "Replaced file was not queued for cleanup");
  const replacementWorker = await fetch(`${url}/functions/v1/cleanup-document-files`, {
    method: "POST",
    headers: { "x-cron-secret": cronSecret, "Content-Type": "application/json" },
    body: "{}",
  });
  assert(replacementWorker.ok, `Replacement cleanup returned HTTP ${replacementWorker.status}`);
  const oldObject = await service.storage.from("CompanyDocuments").info(reservation.path);
  assert(oldObject.error, "Replaced file remained in Storage after cleanup");
  const replacementRead = await clients.editor.storage.from("CompanyDocuments")
    .createSignedUrl(replacement.path, 60);
  assert(!replacementRead.error && replacementRead.data?.signedUrl,
    "Editor could not read replacement");
  const replacementDownload = await fetch(replacementRead.data.signedUrl);
  assert(replacementDownload.ok
    && await replacementDownload.text() === new TextDecoder().decode(replacementBytes),
    "Replacement download bytes differed");

  const revoked = await service.from("resource_shares").delete()
    .eq("resource_id", documentId).eq("resource_type", "document")
    .eq("user_id", editor.id);
  assert(!revoked.error, `Revoke exact Editor share failed: ${revoked.error?.message}`);
  const afterRevoke = await clients.editor.storage.from("CompanyDocuments")
    .createSignedUrl(replacement.path, 60);
  assert(afterRevoke.error, "Revoked Editor could still mint a signed read URL");
  const viewerAfterRevoke = await clients.viewer.storage.from("CompanyDocuments")
    .createSignedUrl(replacement.path, 60);
  assert(!viewerAfterRevoke.error, "Independent company Viewer share was lost");

  requireData(await clients.owner.rpc("miloom_delete_document_with_file", {
    p_document_id: documentId, p_expected_url: replacement.path,
  }), "owner document deletion");
  const worker = await fetch(`${url}/functions/v1/cleanup-document-files`, {
    method: "POST",
    headers: { "x-cron-secret": cronSecret, "Content-Type": "application/json" },
    body: "{}",
  });
  assert(worker.ok, `Cleanup worker returned HTTP ${worker.status}`);
  const cleaned = await worker.json() as { removed?: number; failed?: number };
  assert(cleaned.failed === 0,
    `Cleanup worker returned removed=${cleaned.removed}, failed=${cleaned.failed}`);
  const deletedObject = await service.storage.from("CompanyDocuments").info(replacement.path);
  assert(deletedObject.error, "Deleted document file remained in Storage after cleanup");

  const cascadingDocumentId = crypto.randomUUID();
  requireData(await service.from("company_documents").insert({
    id: cascadingDocumentId, user_id: owner.id, company_id: companyId,
    name: "Disposable cascade document", visibility: "entity",
  }).select("id").single(), "create cascade document");
  const cascadeBytes = new TextEncoder().encode(`MILOOM cascade ${fixture}`);
  const cascadeIssued = await fetch(`${url}/functions/v1/prepare-document-upload`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${owner.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      document_id: cascadingDocumentId, expected_url: null,
      extension: "txt", byte_count: cascadeBytes.length,
    }),
  });
  assert(cascadeIssued.ok, `Cascade upload issuer returned HTTP ${cascadeIssued.status}`);
  const cascade = await cascadeIssued.json() as {
    reservation_id?: string; path?: string; token?: string;
  };
  assert(cascade.reservation_id && cascade.path && cascade.token,
    "Cascade upload issuer omitted reservation details");
  uploadedPaths.push(cascade.path);
  const cascadeUpload = await clients.owner.storage.from("CompanyDocuments")
    .uploadToSignedUrl(cascade.path, cascade.token,
      new Blob([cascadeBytes], { type: "text/plain" }), { contentType: "text/plain" });
  assert(!cascadeUpload.error, `Cascade signed upload failed: ${cascadeUpload.error?.message}`);
  await verifyHostedObject(owner.id, cascade.path, cascadeBytes.length);
  requireData(await clients.owner.rpc("miloom_finalize_document_upload", {
    p_reservation_id: cascade.reservation_id,
  }), "finalize cascade file");
  const deletedCompany = await clients.owner.from("companies").delete().eq("id", companyId);
  assert(!deletedCompany.error, `Owner entity deletion failed: ${deletedCompany.error?.message}`);
  const cascadedDocument = requireData(await service.from("company_documents")
    .select("id").eq("id", cascadingDocumentId), "read cascaded document") as Array<unknown>;
  assert(cascadedDocument.length === 0, "Entity deletion left its document row");
  const cascadeWorker = await fetch(`${url}/functions/v1/cleanup-document-files`, {
    method: "POST",
    headers: { "x-cron-secret": cronSecret, "Content-Type": "application/json" },
    body: "{}",
  });
  assert(cascadeWorker.ok, `Cascade cleanup returned HTTP ${cascadeWorker.status}`);
  const cascadeObject = await service.storage.from("CompanyDocuments").info(cascade.path);
  assert(cascadeObject.error, "Entity deletion left its file in Storage");
  workerCompleted = true;
  console.log(`STAGING DOCUMENT SMOKE PASSED: signed upload/read/replace, Viewer boundary, revoke, entity deletion, cleanup; Storage owner_id ${storageOwner}`);
} catch (error) {
  mainError = error instanceof Error ? error : new Error(String(error));
} finally {
  const cleanupFailures = await removeFixture();
  if (cleanupFailures.length) {
    console.error(`Disposable fixture cleanup incomplete: ${cleanupFailures.join("; ")}`);
  }
  if (mainError) throw mainError;
  if (cleanupFailures.length) throw new Error("Disposable fixture cleanup was incomplete");
}
