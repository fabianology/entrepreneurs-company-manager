import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

let cachedToken: { value: string; createdAt: number } | undefined;

async function providerToken(): Promise<string> {
  if (cachedToken && Date.now() - cachedToken.createdAt < 45 * 60_000) return cachedToken.value;
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const rawKey = Deno.env.get("APNS_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  if (!teamId || !keyId || !rawKey) throw new Error("APNs credentials are not configured");
  const key = await importPKCS8(rawKey, "ES256");
  const value = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key);
  cachedToken = { value, createdAt: Date.now() };
  return value;
}

export async function sendPrivateBriefing(
  deviceToken: string,
  itemCount: number,
  environment: "development" | "production",
  immediate = false,
): Promise<void> {
  const host = environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-topic": Deno.env.get("APPLE_BUNDLE_ID") ?? "com.vibing.miloom",
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: "Miloom",
          body: `${itemCount} ${itemCount === 1 ? "item needs" : "items need"} your attention ${immediate ? "now" : "this week"}.`,
        },
        sound: "default",
      },
      route: "owner_briefing",
    }),
  });
  if (!response.ok) throw new Error(`APNs ${response.status}: ${await response.text()}`);
}
