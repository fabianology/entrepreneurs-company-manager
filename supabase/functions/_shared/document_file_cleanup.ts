export interface DocumentCleanupClient {
  rpc(name: string, args: { p_limit: number }): PromiseLike<{
    data: Array<{ id: string; path: string }> | null;
    error: unknown;
  }>;
  storage: {
    from(bucket: string): {
      remove(paths: string[]): PromiseLike<{ error: unknown }>;
    };
  };
  from(table: string): {
    delete(): {
      eq(column: string, value: string): PromiseLike<{ error: unknown }>;
    };
  };
}

export async function cleanDetachedDocumentFiles(client: DocumentCleanupClient): Promise<{
  removed: number;
  failed: number;
}> {
  const { data, error } = await client.rpc("miloom_pending_document_file_cleanup", { p_limit: 25 });
  if (error) throw new Error("Could not load document cleanup queue");
  let removed = 0;
  let failed = 0;
  for (const file of data ?? []) {
    // The database chooses paths; callers cannot supply one to this worker.
    const result = await client.storage.from("CompanyDocuments").remove([file.path]);
    if (result.error) {
      failed++;
      continue;
    }
    const cleared = await client.from("miloom_document_file_cleanup")
      .delete().eq("id", file.id);
    if (cleared.error) failed++;
    else removed++;
  }
  return { removed, failed };
}
