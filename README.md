<p align="center">
  <img src="Paste/Assets.xcassets/AppIcon.appiconset/icon_256.png" alt="Copydock app icon" width="192" height="192">
</p>

# Copydock — a Paste-style clipboard manager for macOS

**Copydock** is a fork of [gxlself/Paste](https://github.com/gxlself/Paste) rebuilt to look, feel,
and act like [Paste for macOS](https://pasteapp.io/): vivid color-coded cards in a bottom bar,
a clipboard timeline you can search and filter, pinboards with color dots, Paste Stack,
quick-paste shortcuts, and optional iCloud sync.

## The Paste look and feel

- **Cards with colored headers** — every item shows its kind (Text, Link, Color, Image, File),
  the relative time it was copied, and the source app's icon. Header colors follow the source
  app (Messages green, Finder blue, Music pink, …) with a vivid fallback palette.
- **Link and Color cards** — a copied URL renders as a Link card; a six-digit hex code
  (`#1A2B3C`) renders as a full-color swatch. Plain six-digit numbers stay text, so
  verification codes don't turn into swatches.
- **Toolbar** — search field with a filters menu, the current list ("Clipboard") picker,
  pinboard chips with color dots, an add (+) menu, and an actions (⋯) menu.
- **Keyboard-first** — `⇧⌘V` shows Copydock, `⇧⌘C` activates Paste Stack, `⌘1–9` quick-pastes,
  `Space` Quick Looks, `⌘E` edits, `⌘R` renames, `⌘N` new text item, `⇧⌘N` new pinboard,
  `⌘T` pauses, `⌘,` settings, `⌘Q` quits. `⇧Return` pastes as plain text.

## Platforms

| Platform | What it is |
|----------|------------|
| macOS — `Paste` scheme (builds **Copydock.app**) | Menu bar app: clipboard history, global hotkeys, overlay panel, Paste Stack, Pinboards, optional iCloud sync |
| iOS — `Paste-iOS` | Companion app (see SETUP.md for signing/App Group setup) |

## Download

Grab the latest **Copydock-*-macos.dmg** from
[Releases](https://github.com/corismix/Paste/releases), drag Copydock into Applications.
Builds are ad-hoc signed: right-click → Open, or
`xattr -dr com.apple.quarantine /Applications/Copydock.app`.

## Build

```bash
git clone https://github.com/corismix/Paste.git
cd Paste
open Paste.xcodeproj   # select the "Paste" scheme, My Mac, Cmd-R
```

CI builds, tests, and uploads a dmg on every push to `main`; `v*` tags publish a GitHub release.

## Privacy

History stays on your device (or your private iCloud if you enable sync). Nothing is sent
anywhere else. Excluded apps, confidential-content filtering, retention limits, and pause
(`⌘T`) are in Settings.

## Credits

Upstream: [gxlself/Paste](https://github.com/gxlself/Paste) — the app this fork builds on.
Design target: [Paste](https://pasteapp.io/) by Paste Team ApS (no affiliation; this is an
independent look-and-feel rebuild for personal use).
