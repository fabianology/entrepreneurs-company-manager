# Production scoped-secret acceptance — 2026-10-19 PDT

Scope: synthetic, single-resource collaborator-password flow on installed Miloom
TestFlight 1.0(16), built from reviewed commit `aabd35df`, after Production
migration `202610010001` was applied. No real password was used.

## Evidence

- The owner and Editor each reported a Production vault unlocked on separate
  physical iPhones running build 16.
- The owner created two synthetic services in a synthetic entity, activated
  their independent credential keys, and confirmed Face ID reveal on both.
- Only the first service was shared as Editor. The recipient saw that service
  and its Edit control, but not the sibling. The recipient requested credential
  access; the owner approved that exact device request; the recipient then
  reported Face ID reveal of the first service's synthetic login and password.
- After resource-only Editor removal, the recipient's refreshed dashboard no
  longer showed the synthetic entity. A read-only Production query found zero
  direct shares, one revoked and zero active device grants for the first
  service. Its old key was retired and replacement key version 2 was active.
  The sibling had zero shares and zero device grants and remained on version 1.
- The owner reported reveal working again after replacing the first service's
  key. The owner then deleted both exact synthetic services in the native app.
  A read-only Production query by their previously captured IDs returned zero
  subscription rows, resource shares, secret versions, and device wraps.

These observations pass the bounded synthetic grant, isolation, revocation,
owner-rotation, and cleanup check. Native actions are owner-reported; backend
counts were read independently. This does not establish a professional security
audit, test a retained stolen client token, or assert whole-app release readiness.
Credential access remains explicit per resource and device, not a global grant.

No source changes or new backend migration were made for this acceptance run.
The independent AI code-review PASS and focused tests belong to exact commit
`aabd35df`; see the canonical project-management handoffs for their limits.
