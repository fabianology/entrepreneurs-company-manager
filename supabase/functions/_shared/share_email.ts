export const SHARE_ROLES = ["Viewer", "Editor", "Admin"] as const;

export type ShareRole = (typeof SHARE_ROLES)[number];

const resourceNames: Record<string, string> = {
  company: "an entity",
  all_subscriptions: "all subscriptions for an entity",
  subscription: "a subscription",
  all_documents: "all documents for an entity",
  document: "a document",
  all_financials: "all financial resources for an entity",
  institution: "a financial institution",
  card: "a financial card",
  loan: "a loan",
};

export function isShareRole(value: unknown): value is ShareRole {
  return typeof value === "string" && SHARE_ROLES.includes(value as ShareRole);
}

export function resourceName(value: unknown): string | null {
  return typeof value === "string" ? resourceNames[value] ?? null : null;
}

export function isEmail(value: unknown): value is string {
  return typeof value === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    switch (character) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      case "'": return "&#39;";
      default: return character;
    }
  });
}

export function shareEmailSubject(resourceType: string): string | null {
  const readableResource = resourceName(resourceType);
  return readableResource ? `You've been invited to collaborate on ${readableResource}` : null;
}

export function shareEmailHtml(input: {
  inviter: string;
  invitationUrl: string;
  role: ShareRole;
  resourceType: string;
}): string | null {
  const readableResource = resourceName(input.resourceType);
  if (!readableResource) return null;

  const inviter = escapeHtml(input.inviter);
  const invitationUrl = escapeHtml(input.invitationUrl);
  const role = escapeHtml(input.role);
  const resource = escapeHtml(readableResource);

  return `<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
  <body style="margin:0;padding:0;background:#000000;color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#000000;padding:40px 20px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#1c1c1e;border:1px solid #343438;border-radius:20px;overflow:hidden;text-align:left;">
          <tr><td style="padding:30px 32px;text-align:center;border-bottom:1px solid #343438;">
            <div style="color:#c1aa78;font-size:28px;font-weight:750;letter-spacing:-0.5px;">Miloom</div>
          </td></tr>
          <tr><td style="padding:36px 32px;">
            <h1 style="margin:0 0 20px;font-size:24px;line-height:1.2;color:#ffffff;">You’ve been invited</h1>
            <p style="margin:0 0 16px;font-size:16px;line-height:1.6;color:#c7c7cc;">
              ${inviter} invited you to collaborate on <strong style="color:#ffffff;">${resource}</strong> as <strong style="color:#ffffff;">${role}</strong>.
            </p>
            <p style="margin:0 0 12px;font-size:16px;line-height:1.6;color:#c7c7cc;">Open Miloom to review the invitation and access the shared resource.</p>
            <p style="margin:0 0 30px;font-size:13px;line-height:1.5;color:#8e8e93;">This invitation link expires in 7 days and can be used only once.</p>
            <div style="text-align:center;">
              <a href="${invitationUrl}" style="display:inline-block;padding:14px 26px;border-radius:999px;background:#c1aa78;color:#111111;font-size:16px;font-weight:700;text-decoration:none;">Review Invitation</a>
            </div>
          </td></tr>
          <tr><td style="padding:22px 32px;background:#111111;border-top:1px solid #343438;text-align:center;color:#8e8e93;font-size:13px;line-height:1.5;">
            © 2026 Miloom. Secure entity and financial management.
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}
