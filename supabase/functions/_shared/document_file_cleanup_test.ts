import { cleanDetachedDocumentFiles, type DocumentCleanupClient } from "./document_file_cleanup.ts";

const assert = (condition: boolean, message: string) => {
  if (!condition) throw new Error(message);
};

Deno.test("cleanup removes only server-queued paths and retains failures", async () => {
  const removedPaths: string[] = [];
  const clearedIDs: string[] = [];
  const fake: DocumentCleanupClient = {
    rpc: async (_name, args) => {
      assert(args.p_limit === 25, "Cleanup page must be bounded");
      return { data: [{ id: "a", path: "owner/a.pdf" }, { id: "b", path: "owner/b.pdf" }], error: null };
    },
    storage: { from: (bucket) => {
      assert(bucket === "CompanyDocuments", "Only the document bucket may be cleaned");
      return { remove: async (paths) => {
        removedPaths.push(...paths);
        return { error: paths[0].endsWith("b.pdf") ? new Error("transient") : null };
      } };
    } },
    from: (table) => {
      assert(table === "miloom_document_file_cleanup", "Only the queue row may be cleared");
      return { delete: () => ({ eq: async (_column, id) => {
        clearedIDs.push(id);
        return { error: null };
      } }) };
    },
  };
  const result = await cleanDetachedDocumentFiles(fake);
  assert(result.removed === 1 && result.failed === 1, "Result counts are wrong");
  assert(removedPaths.join(",") === "owner/a.pdf,owner/b.pdf", "Paths changed");
  assert(clearedIDs.join(",") === "a", "Failed object was removed from the retry queue");
});
