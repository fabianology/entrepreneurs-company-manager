export interface DocumentUploadRequest {
  document_id: string;
  expected_url: string | null;
  extension: string;
  byte_count: number;
}

export function parseDocumentUploadRequest(value: unknown): DocumentUploadRequest {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid upload request");
  }
  const input = value as Record<string, unknown>;
  if (typeof input.document_id !== "string"
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.document_id)
    || !(input.expected_url === null || typeof input.expected_url === "string")
    || typeof input.extension !== "string"
    || !/^[a-z0-9]{1,12}$/i.test(input.extension)
    || !Number.isInteger(input.byte_count)
    || (input.byte_count as number) < 1
    || (input.byte_count as number) > 25 * 1024 * 1024) {
    throw new Error("Invalid upload request");
  }
  return input as unknown as DocumentUploadRequest;
}
