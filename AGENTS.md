# AGENTS.md

Copydock is a fork of gxlself/Paste. The Xcode target and scheme are still named `Paste`, but the
macOS product is **Copydock.app**; only product names and bundle IDs were renamed, not directories.

## Build, test

No SwiftPM/CocoaPods/Carthage, no linter or formatter — Xcode warnings and tests are the checks.
`DEVELOPMENT_TEAM` is intentionally empty; do not fill it in.

```bash
# Unit tests (Swift Testing). Use this day-to-day.
xcodebuild -project Paste.xcodeproj -scheme Paste -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:PasteTests

# Full test action. Adds PasteUITests, whose runner can crash in a non-GUI session
# ("Early unexpected exit") — that is environmental, not a code regression.
xcodebuild -project Paste.xcodeproj -scheme Paste -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

# CI build (produces ad-hoc signed .../Release/Copydock.app)
xcodebuild -project Paste.xcodeproj -scheme Paste -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
  CODE_SIGN_ENTITLEMENTS="Paste/PasteDistribution.entitlements" build
```

`-scheme Paste-iOS` / `Paste-Keyboard` need a signing team; see SETUP.md.

## Layout

The project uses Xcode file-system synchronized folders: a `.swift` file added under a target
directory joins that target automatically. Do not edit `project.pbxproj` to add files.

- `Paste/` — macOS app (deployment target 15.3). `App/` = lifecycle and window/hotkey coordinators,
  `Features/<area>/` = SwiftUI, `Services/` = clipboard/hotkey/paste-stack logic, `Persistence/` =
  its own Core Data stack.
- `Paste-Shared/` — compiled into all three targets (no framework). iOS and the keyboard use
  `SharedCoreDataStack`/`ClipboardRepository`; macOS uses `Paste/Persistence/CoreDataStack.swift`
  and shares only the model/tag types (`ItemTag`, `SharedClipboardItemType`).
- `Paste-iOS/`, `Paste-Keyboard/` — iOS 16 app and keyboard extension; communicate via App Group
  `group.dev.corismix.copydock`.
- `PasteTests/` — Swift Testing (`import Testing`, `@Test`, `#expect`); do not add XCTest here.
  `PasteUITests/` is XCTest.
- `docs/` — the GitHub Pages site (HTML), not app documentation. `scripts/deploy-docs-gh-pages.sh`
  force-pushes it to the `gh-pages` branch.

## Footguns

- Do not add iCloud or `aps-environment` entitlements to `Paste/PasteDistribution.entitlements`;
  CI ad-hoc signs with it and restricted entitlements break app launch.
- Identifiers in use: `dev.corismix.copydock`, `iCloud.dev.corismix.copydock`,
  `group.dev.corismix.copydock` (`Paste/Support/Constants.swift`,
  `Paste-Shared/SharedCoreDataStack.swift`).
- Releases are automated: pushing a `v*` tag makes `.github/workflows/macos.yml` publish a dmg.
  `docs/RELEASE_MACOS.md`, `docs/RELEASE_IOS.md`, `scripts/build-macos-github-release.sh`, and
  SETUP.md §1 (App Group) still describe upstream Paste and are stale or broken for this fork.
