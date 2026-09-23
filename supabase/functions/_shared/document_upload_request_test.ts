import { parseDocumentUploadRequest } from "./document_upload_request.ts";

const valid = {
  document_id: "60000000-0000-0000-0000-000000000001",
  expected_url: null,
  extension: "pdf",
  byte_count: 1024,
};
const assert = (condition: boolean) => { if (!condition) throw new Error("Assertion failed"); };

Deno.test("signed document upload request accepts only bounded exact-document input", () => {
  assert(parseDocumentUploadRequest(valid).byte_count === 1024);
  for (const bad of [
    { ...valid, document_id: "not-a-document" },
    { ...valid, expected_url: undefined },
    { ...valid, extension: "../pdf" },
    { ...valid, byte_count: 0 },
    { ...valid, byte_count: 26 * 1024 * 1024 },
    { ...valid, byte_count: "1024" },
  ]) {
    let rejected = false;
    try { parseDocumentUploadRequest(bad); } catch { rejected = true; }
    assert(rejected);
  }
});
