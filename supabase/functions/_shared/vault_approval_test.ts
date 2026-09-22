import { normalizeUUID } from "./vault_approval.ts";

Deno.test("normalizeUUID accepts equivalent Swift and Postgres UUID text", () => {
  const swift = "A0B1C2D3-E4F5-4678-9ABC-DEF012345678";
  const postgres = "a0b1c2d3-e4f5-4678-9abc-def012345678";
  if (normalizeUUID(swift) !== postgres) {
    throw new Error(
      "Expected uppercase UUID text to normalize to the Postgres representation",
    );
  }
});

Deno.test("normalizeUUID rejects malformed identifiers", () => {
  for (
    const value of [null, 42, "not-a-uuid", "a0b1c2d3e4f546789abcdef012345678"]
  ) {
    if (normalizeUUID(value) !== null) {
      throw new Error(
        `Expected malformed UUID to be rejected: ${String(value)}`,
      );
    }
  }
});
