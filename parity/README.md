# Parity harness

Tools for measuring Copydock against the installed Paste.app (`/Applications/Paste.app`,
`com.wiheads.paste`, 6.6.2) and keeping a rolling gap list.

## Layout

- `reference/extracted/` — raw reference data pulled from Paste: localization strings, Info.plist,
  entitlements, defaults, Core Data schema, MCP tool surface.
- `reference/feature-inventory.md` — Paste feature areas mapped to Copydock status.
- `reference/behavior-notes.md` — measured geometry, defaults, DB model, MCP surface, caveats.
- `checklist.md` — ordered remaining gaps.
- `captures/` — gitignored screenshots/AX dumps per app and state.
- `harness/` — tools (all standalone Swift scripts; `harness/build.sh` compiles them to `.build/`).

## Usage

```bash
parity/harness/build.sh                      # compile axdump, imagediff, pixscan
parity/harness/snapshot.sh paste panel-open  # capture a state (AX tree + windows + PNGs + defaults)
parity/harness/snapshot.sh copydock panel-open
parity/harness/diff.sh parity/captures/paste/panel-open parity/captures/copydock/panel-open
parity/harness/.build/pixscan <png> --col 296        # colour runs down a column (2x pixels)
parity/harness/.build/imagediff a.png b.png --out heat.png
python3 parity/harness/paste-mcp.py tools            # reference app's MCP tool surface (local OAuth)
python3 parity/harness/paste-mcp.py call search '{"query": "..."}'
```

The reference app's local MCP server must be reachable at `http://127.0.0.1:39725/mcp` with a
locally cached OAuth token; the harness reads that local cache, so the oracle works from this
repo without additional setup.

## Rules

- Captures contain clipboard contents; `parity/captures/` stays gitignored.
- Paste's data (`~/Library/Containers/com.wiheads.paste`, group container) is read-only reference.
- The local reference build may differ from official binaries. Sanity-check suspicious details
  against official docs/screenshots before matching them.
