const permanentTokenReasons = new Set([
  "BadDeviceToken",
  "DeviceTokenNotForTopic",
  "Unregistered",
]);

export function shouldPrunePushToken(status: number, reason?: string): boolean {
  return status === 410 || (reason != null && permanentTokenReasons.has(reason));
}
