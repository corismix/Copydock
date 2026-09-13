# Paste 6.6.2 behavior notes (measured)

## Bundle / runtime

- Bundle: `com.wiheads.paste`, 6.6.2 (18766), universal x86_64+arm64, min macOS 14,
  `LSUIElement` (agent app), URL scheme `paste://`, CloudKit sharing enabled.
- Entitlements: **not sandboxed**, `files.user-selected.read-only`, `network.client` (Direct build).
- Note: the local reference build may differ from official binaries; verify odd values against
  official docs/screenshots before matching.
- Binary keeps ~4,200 Swift-mangled symbols (`nm -a`), so `xcrun swift-demangle` gives a usable
  symbol inventory.

## Measured main panel (screencapture @2x, panel window 1470×332)

| Property | Value |
| --- | --- |
| Panel background | `#202020` (`#1f1f1f` between cards); content inset ~8pt left/right, ~5pt top |
| Top bar | 60pt; search button 34×34 at x=477 (glyph 17×11), chip row 519–951, `+` 959, `…` 1413 |
| Chips | "Clipboard" selected: dark fill + 1px border + clock, 34pt tall; pinboard chips: 8pt colour dot + label |
| Cards | 240×240 visible, interior ~232 wide, pitch 256 (gap ~16–24), margins ~24–26, radius ~12 |
| Header | 48pt solid source-app colour; kind 13pt semibold at +10pt; time ~11pt at +28pt; leading 14pt |
| App icon | ~56pt, flush to card top-right (AX reports 78×78 incl. shadow), overlaps header/body boundary |
| Body | `#141414`; text 12pt `#dcdcdc`-ish, first line ~13pt below header, leading padding ~16pt; transparent images show a checkerboard |
| Footer | centered 11pt grey at bottom (~9pt padding); char count / "2940 × 1912"; absent on link items |
| Selection | blue `#007aff` border ~2.5–3pt; selected card body slightly lighter (`#1e1e1e`–`#202020`) |
| Empty-state strings | "History is empty", "Pinboard is empty", "Nothing found" |
| Time format | full words: "5 minutes ago", "20 minutes ago" |

## Defaults (`defaults read com.wiheads.paste`, abbreviated)

`isDirectPasteEnabled=1`, `isLinkPreviewsEnabled=0`, `isPasteAsPlainTextEnabled=0`,
`isSoundEffectsEnabled=0`, `isStatusItemEnabled=0`, `isSyncEnabled=0`, `useBinaryPlist=1`,
`selectedListIdentifier=sharedPasteboardHistory`, `pasteStackDirection=bottom`,
`pasteStackShortcut={keyCode:8,modifiers:...}` (⌘⇧C), `nextPinboardShortcut` (keyCode 124 →),
`previousPinboardShortcut` (keyCode 123 ←), `plainTextModifierFlags=131072` (⇧),
`ignoredBundleIdentifiers=[]`, `ignoredPasteboardTypes=[com.typeit4me..., ...]`,
`indexingState`/`indexHistoryTokenData` (CoreSpotlight OCR index),
`NSWindow Frame PasteAppMainWindow... = 0 0 1470 332`, `paste-stack-frame = 497 726 264 76`,
`mcpPort` (default 39725).

## Activation / shortcuts

- Activate Paste: ⇧⌘V (onboarding copy confirms).
- Settings sections: General, Privacy, Shortcuts, MCP & AI Tools, Subscription.
- Shortcuts: Activate Paste, Activate Paste Stack, Quick Paste, Plain Text mode, previous/next Pinboard.

## Data model (Core Data SQLite)

`db.sqlite` at `~/Library/Containers/com.wiheads.paste/Data/Library/Application Support/Paste/`.
Key entities: `ZITEMENTITY` (type, data, device, list, sourceApplication, checksum, identifier,
title, rawPreview, displayOrderInPinboard), `ZITEMDATAENTITY` (raw pasteboard items), `ZLISTENTITY`
(pinboards: type, name, metadata, attributes, shareRecord), `ZLISTMETADATAENTITY`, `ZAPPLICATIONENTITY`,
`ZDEVICEENTITY`, `ZOBJECTSHARE`/`ZOBJECTMETADATA` (CloudKit sharing). Unique index on item checksum
and identifier.

## Paste MCP (6.6+, local server)

- Server `PasteMCP` on `http://127.0.0.1:39725/mcp` (OAuth via PKCE + dynamic client registration;
  no static token). Official bridge: `npx -y @pasteapp/mcp` (OAuth, caches at
  `~/Library/Application Support/paste-mcp/tokens.json`).
- Local integration: configure the reference server in any MCP-capable client; `paste-mcp.py`
  reads the locally cached OAuth token.
- 11 tools: `search`, `read_item`, `create_item`, `update_item`, `delete_item`, `list_pinboards`,
  `create_pinboard`, `rename_pinboard`, `delete_pinboard`, `add_item_to_pinboard`,
  `remove_item_from_pinboard`. Full schemas in `extracted/mcp-tools.json`.

## Menu bar structure (`Paste` menu)

About Paste · New Text Item · Settings… · Help (Getting Started, Keyboard Shortcuts, Help Center,
Product Updates, Feature Request, Contact Support, Start Diagnostics) · Paste on Twitter ·
Pause Paste (Pause, 15m, 30m, 1h, 3h, 8h) · Quit Paste.

## Caveats

- Reference use stays read-only and local; the reference app's license terms apply.
- Settings-window screenshots and AX dumps of the MCP pane live in `captures/paste/settings-mcp/`.
