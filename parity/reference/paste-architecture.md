# Paste architecture (initial binary analysis)

Method: `nm -a` + `xcrun swift-demangle` on `Paste.app/Contents/MacOS/Paste`
(full dump: `extracted/paste-symbols.txt`, gitignored). ~4,200 Swift symbols retained, no stripping.

## Modules

- `PasteCore` — data + view models: `ItemEntity`, `ItemCollectionViewModel`,
  `ItemPreviewViewModel`, `ListEntity`, `ListAttributes`, `ListCollectionViewModel`,
  `ManagedObjectObserver` (Combine-based Core Data observation).
- `PasteUI` — AppKit views: `CollectionView`, `CollectionViewCell`, `WindowController`,
  `WindowPresentationMode`, `LayerBackedView`, `ReorderableStackView`, plus
  `CellTransitionManager` / `CellSelectionManager`.
- Feature bundles (separate Swift packages, resources visible in the app bundle):
  `PasteOnboarding`, `PasteWhatsNew`, `PasteMCP`, `PasteSystemPermissions`,
  `PasteLicensingAppStore`, `PasteLicensingDirect`, `PasteLocalization`.

## Interpretation

- The **main panel is AppKit** (`NSCollectionView` + custom cells + transition/selection
  managers), not SwiftUI. Copydock's SwiftUI `LazyHStack` approximates the look, but feel-level
  details (rubber-banding, cell transitions, keyboard selection navigation) come from these
  AppKit components.
- `PasteCore` is a testable, UI-free model layer; Copydock's `ClipboardViewModel` plays the same
  role in a single module.
- `Combine` + Core Data observers drive updates; Copydock uses the same stack.

## Linked frameworks (otool)

`AppKit`, `SwiftUI`, `Combine`, `CoreData`, `CloudKit`, `CoreSpotlight`, `Vision`, `VisionKit`,
`WebKit`, `LinkPresentation`, `QuickLook(UI)`, `CryptoKit`, `AudioToolbox`, `Carbon`,
`ServiceManagement`, `UserNotifications`, `Symbols`, `StoreKit`.

## Symbols

- Symbols are mangled Swift (`_$s...`); `xcrun swift-demangle` on the `nm` dump
  (`extracted/paste-symbols.txt`) is the fastest architecture map. Deeper static-analysis tooling
  is local-only and not part of this repo.
