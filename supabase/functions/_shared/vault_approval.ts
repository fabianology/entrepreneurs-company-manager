const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function normalizeUUID(value: unknown): string | null {
  if (typeof value !== "string" || !uuidPattern.test(value)) return null;
  return value.toLowerCase();
}
