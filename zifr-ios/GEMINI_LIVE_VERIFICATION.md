# Gemini 3.8 Live implementation and verification

Updated September 16, 2026. Implementation is present and the authenticated Gemini 3.8 Live handshake passed. Physical-device audio and live-action acceptance remain open. The Mac is unlocked and the normally signed simulator build has a working persisted login.

## Implemented

- Native voice uses `models/gemini-3.8-live`, Aoede, 16 kHz PCM input and 24 kHz playback, and the existing authenticated Supabase WebSocket proxy.
- Setup confirmation gates microphone transmission. The client serializes socket state and outbound messages on the main actor, uses a 15-second setup timeout, rejects stale socket callbacks, and stops retrying terminal account/model/allowance failures.
- Input uses `realtimeInput.audio`; input/output transcription, interruption, completion, tool cancellation, expiry, and resumption events are decoded.
- Temporary disconnects resume from the latest safe checkpoint with bounded retries. Audio captured after a checkpoint is not replayed. A missing/unusable checkpoint requires an explicit fresh restart.
- All tool requests are queued. Confirmations run one at a time, cancellation is respected, and repeated completed call IDs return the cached result without executing a second write. Live tools explicitly use BLOCKING behavior; REST tools omit it.
- Required tool arguments are validated, including whole-number financial amounts. Unknown/nested JSON arguments do not break message decoding.
- Voice processing enables echo cancellation for simultaneous microphone input and assistant playback. Interruptions flush playback. The orb follows microphone and scheduled playback levels.
- Microphone input pauses for mute, confirmations, backgrounding, audio interruptions, connection recovery, and local credential speech. Capture tokens invalidate buffered samples across privacy pauses. Local login identifiers are excluded from voice portfolio context.
- Native Canvas renders the animated blue mesh and amber core. Reduced Motion displays a static orb; animation pauses when inactive. The screen includes transient transcripts, mute, Type Instead, and End controls, without routine state labels or a debug overlay.
- The existing Type Instead request now uses the REST proxy rather than the WebSocket-only route. Its model is unchanged.

## Verification completed

- Debug simulator builds succeeded for the `Zifr` scheme on the iPhone 17 Pro simulator (iOS 26.4). The authenticated check uses `/tmp/miloom-gemini38-signed` with normal simulator signing. Earlier unsigned builds compiled successfully but could not retrieve the Supabase Keychain session, even after successful UI login.
- Debug device build succeeded with the existing signing configuration in `/tmp/miloom-fx-device`. Installed and launched `com.vibing.miloom` on iPhone FX (iPhone 15 Pro Max) on September 16. Installation and launch do not establish audio or live-action acceptance.
- Focused suite with live integration enabled: 22 tests executed, 22 passed, 0 skipped, 0 failures at 11:27 PDT on September 16. This includes the authenticated service handshake; other protocol scenarios use an injected mock transport. Without the opt-in environment variable, the service test intentionally skips.
- Tests cover setup/audio gating, mixed audio/transcript events, interruption ordering, multiple audio parts, session recovery, missing checkpoints, timeout/cancellation, five-attempt retry exhaustion, cancellation during reconnect, terminal errors, tool queue/cancellation/deduplication/validation, integer amounts, transcript turn boundaries, capture privacy tokens, and omission of login identifiers from voice context.
- Inspected two procedural orb renders and a hosted SwiftUI voice-panel snapshot with synthetic conversation text. Hosted rendering was needed because ImageRenderer omits ScrollView's UIKit-backed content.
- `git diff --check` passed. Existing unrelated working-tree changes were preserved; changes made for this task are inside `zifr-ios`. No dependencies, Supabase contracts, signing settings, entitlements, or deployment targets were changed. No backend or App Store deployment was performed.

Reproduce the focused checks from the repository root, selecting an available simulator:

```sh
xcodebuild -project zifr-ios/Zifr.xcodeproj -scheme Zifr \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/miloom-gemini38-signed \
  -only-testing:ZifrTests/GeminiLiveTests test
```

## Live-service result

- `testAuthenticatedLiveHandshakeWhenOptedIn` passed on September 16 at 11:25 PDT in 0.680 seconds, with `MILOOM_LIVE_INTEGRATION=1`. The actual Gemini client reached `.ready` after server setup confirmation through the deployed authenticated proxy. No microphone audio or portfolio data was sent.
- Use normal simulator signing for this check; do not use `CODE_SIGNING_ALLOWED=NO`. Credentials were entered only through the app login UI and were not added to project files. Explicitly opted-in runs now fail if authentication is unavailable rather than reporting a skipped test.
- Foreground UI inspection confirmed the signed-in dashboard after relaunch. The current dashboard control opens Briefing; its `showAssistant` flag is only set by the onboarding spotlight. CompanyDetailView also has an assistant presentation without an ordinary launch action. The hosted orb snapshot therefore remains the visual evidence for the voice panel; normal in-app voice navigation still needs an entry point.

## Open acceptance checks

1. **Physical iPhone audio:** Verify speaker and Bluetooth playback, interruption without echo loops, response timing, mute/unmute, denied microphone permission, route changes, system interruption, background/foreground, and local credential speech with a synthetic test value.
2. **Live actions and recovery:** With disposable test data, confirm/cancel draft changes, verify duplicate tool calls do not write twice, exercise connection loss during speech and a pending confirmation, and check that allowance errors stop the session. The deployed proxy accepts the connection-test setup; a real tool-bearing conversation is still unverified.

Do not mark the full live-voice acceptance complete from build or mocked protocol tests alone.

## Primary references

- https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live
- https://ai.google.dev/api/live
- https://ai.google.dev/gemini-api/docs/live-api/capabilities
- https://ai.google.dev/gemini-api/docs/live-api/session-management
