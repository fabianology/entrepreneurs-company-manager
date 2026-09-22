import { assertEquals } from "jsr:@std/assert@1";
import {
  escapeHtml,
  isEmail,
  isShareRole,
  resourceName,
  shareEmailHtml,
  shareEmailSubject,
} from "./share_email.ts";

Deno.test("sharing email policy accepts only supported roles, resources, and email addresses", () => {
  assertEquals(isShareRole("Viewer"), true);
  assertEquals(isShareRole("Owner"), false);
  assertEquals(resourceName("all_financials"), "all financial resources for an entity");
  assertEquals(resourceName("password_vault"), null);
  assertEquals(isEmail("collaborator@example.com"), true);
  assertEquals(isEmail("not-an-email"), false);
});

Deno.test("sharing email content is Miloom branded and escapes server-loaded values", () => {
  const html = shareEmailHtml({
    inviter: 'owner@example.com<script>alert("x")</script>',
    invitationUrl: "https://miloom.co/invite?token=abc123",
    role: "Admin",
    resourceType: "document",
  });

  assertEquals(html?.includes("Miloom"), true);
  assertEquals(html?.includes("https://miloom.co/invite?token=abc123"), true);
  assertEquals(html?.includes("expires in 7 days"), true);
  assertEquals(html?.includes("Zifr"), false);
  assertEquals(html?.includes("<script>"), false);
  assertEquals(html?.includes("&lt;script&gt;"), true);
  assertEquals(shareEmailSubject("document"), "You've been invited to collaborate on a document");
  assertEquals(escapeHtml(`&<>"'`), "&amp;&lt;&gt;&quot;&#39;");
});
