# Copydock → Paste parity checklist

Ordered by impact. `[x]` done, `[~]` partial, `[ ]` not started.

## Done (main panel look & feel, first pass)

- [x] Panel height 332 (was 280), dark `#1f1f1f` background (was light-grey vibrancy), rounded top corners 12
- [x] Cards 240×240 (was 204 tall / 255 wide); pitch 256; horizontal margin 24
- [x] Header 48pt (was 44); time 11pt; full-word relative times (was "1 hr ago")
- [x] App icon 56pt flush to card top-right (was 40pt inset)
- [x] Body `#141414` (was `#1c1c1f`); text 12pt with 16pt leading padding
- [x] Footer: centered text only, no bar/divider (was a background bar)
- [x] Top bar 60pt (was ~42); 34×34 controls; unified Clipboard + pinboard chips (removed list dropdown)
- [x] Link cards show the raw URL and no character footer (Paste behaviour)
- [x] Empty states match Paste wording: "History is empty" / "Pinboard is empty" / "Nothing found"
- [x] Reference MCP oracle wired locally (OAuth) + `paste-mcp.py` helper

## Next (in order)

- [ ] Preview pane: paste-parity layout/behaviour for Space/Quick Look (space key, arrow keys)
- [ ] Quick Paste: verify ⌘1–9 paste directly and badge offsets match Paste
- [ ] Panel dismissal: Escape / click-away / Return semantics; re-show while visible
- [ ] Pause durations 15m/30m/1h/3h/8h with countdown ("Paused until …")
- [ ] Search: filters by app/date/type/pinboard (Paste shows a filter popover)
- [ ] OCR search (Vision + CoreSpotlight index) — larger lift
- [ ] Pinboard management UI (create/rename/recolour/delete from prefs or panel)
- [ ] Item editing: image rotate/remove-background; rich text toolbar (Paste edit-item toolbar)
- [ ] "Ignore transient/confidential content" privacy toggles
- [ ] History retention (time-based) incl. Forever
- [ ] Open at login + run in background + menu bar icon toggles (Paste General pane)
- [ ] `paste://` URL scheme and App Intents (Siri & Shortcuts)
- [ ] MCP server for Copydock (mirror Paste's 11-tool surface)
- [ ] iCloud sync + shared pinboards (large lift; needs entitlements)
- [ ] What's New / diagnostics surfaces (low priority)

## Verification loop

```bash
parity/harness/snapshot.sh copydock panel-open-passN
parity/harness/.build/pixscan parity/captures/copydock/panel-open-passN/window-0.png --col 296
# compare against parity/captures/paste/panel-open/
xcodebuild -project Paste.xcodeproj -scheme Paste -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:PasteTests
```

Paste state captures use the ⇧⌘V hotkey; quit Paste before capturing Copydock (both register it).
