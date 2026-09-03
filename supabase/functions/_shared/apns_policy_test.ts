import { assertEquals } from "jsr:@std/assert@1";
import { shouldPrunePushToken } from "./apns_policy.ts";

Deno.test("permanently invalid APNs tokens are pruned", () => {
  assertEquals(shouldPrunePushToken(400, "BadDeviceToken"), true);
  assertEquals(shouldPrunePushToken(400, "DeviceTokenNotForTopic"), true);
  assertEquals(shouldPrunePushToken(410, "Unregistered"), true);
});

Deno.test("temporary APNs failures retain the device token", () => {
  assertEquals(shouldPrunePushToken(429, "TooManyRequests"), false);
  assertEquals(shouldPrunePushToken(500, "InternalServerError"), false);
});
