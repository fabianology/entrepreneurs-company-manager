# zifr-ios Working Agreement

## Scope

- Work only on the native Swift iOS app inside `zifr-ios`.
- Do not edit sibling React Native, web, desktop, root-app, or backend files unless the user explicitly expands scope.
- Read `PROJECT_HANDOFF.md` for context. Treat the current code, Git state, and the user's direct request as authoritative.

## Preserve work and secrets

- Check Git status before editing and preserve all existing local changes.
- Never discard, revert, overwrite, or reformat unrelated work.
- Do not stage, commit, stash, pull, or push unless the user explicitly asks. When asked, scope Git staging to `zifr-ios` unless directed otherwise.
- Never expose or commit credentials. Keep `Zifr/Secrets.local.xcconfig` and local environment values private.
- Do not edit generated output in `build/`, `DerivedData/`, or Xcode `xcuserdata`.

## Implementation

- Target the `Zifr` iOS scheme and preserve iOS 17 compatibility unless a task explicitly changes deployment requirements.
- Follow the existing SwiftUI/Observation architecture: `AppState` for shared data, `AppViewModel` for current coordination, and `DataRepository` for persistence.
- Reuse existing colors, glass modifiers, sheet cards, and shared components before adding new design patterns.
- Keep changes focused. Do not combine feature work with broad renames, architecture rewrites, dependency upgrades, or repository cleanup.
- Ask before adding production dependencies or changing Supabase contracts, entitlements, signing, bundle identifiers, or deployment targets.
- When adding a Swift file, ensure it belongs to the `Zifr` target/project configuration.

## Verification and handoff

- Run relevant non-destructive checks after changes. For meaningful Swift changes, build the `Zifr` scheme for an available iPhone simulator when feasible.
- Report exactly what was verified. Do not claim tests passed when no applicable tests exist or a build was not run.
- Before finishing, confirm that no out-of-scope files changed and summarize the changed files, verification result, and current Git status.
