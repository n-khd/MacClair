# Architecture

MacClair is a single SwiftUI app plus one helper executable. No server, no database, no
dependency: only the macOS SDK. This page is the map you need before touching a scanner or the
Trash code. Contribution rules live in [../CONTRIBUTING.md](../CONTRIBUTING.md).

## Shape of the thing

```
MacClair.app
├── Contents/MacOS/MacClair        SwiftUI app (all UI + scanners)
└── Contents/MacOS/macclair-mcp    stdio JSON-RPC server, linked against the same scanners
```

Both binaries compile from the same sources, so a fix in `Scanner.swift` or `SafeTrash.swift`
reaches the UI and the MCP server at once. `build-app.sh` builds the app, then the helper, then
assembles the bundle (icon, hero image, `*.lproj`, optional `Sparkle.framework`) and signs it.

## Data flow

```
scan (read-only)                    user confirms                move
─────────────────                   ─────────────                ────
Cleaner.scan()      ──► ScanReport ──► selection ──► SafeTrash.capture()  ──► TrashCandidate
  Scanner.swift                                        │  records size, mtime
                                                       │  device + inode
                                                       ▼
                                              user clicks "Move to Trash"
                                                       ▼
                                        SafeTrash.validate()  (size, mtime, dev, inode unchanged)
                                                       ▼
                                        FileManager.trashItem  ──►  macOS Trash
                                                       ▼
                                        ActivityStore.record(kind:freed:moved:)
```

The same three-step gate (`capture` → `validate` → `moveToTrash`) is used for duplicates
(`validateDuplicate`, which also re-hashes the keeper), for the uninstaller
(`AppUninstaller.isAllowed`) and for the MCP server. **Nothing in the app calls
`FileManager.removeItem` on user files.**

## Modules

| File | Lines | Responsibility |
|---|---|---|
| `Scanner.swift` | ~220 | `Cleaner.scan()` inventories caches, logs, old installers, disk images; `CleanupCategory`, `CleanupItem`, `ScanReport` (with `unreadablePaths` and `stoppedAtLimit`), then the moves |
| `SafeTrash.swift` | ~205 | Location and identity checks, duplicate planning, the only Trash gate |
| `Insights.swift` | ~245 | `InsightScanner`: large files (> 25 MB), SHA-256 duplicate groups, installed apps, `SystemSnapshot`, `SecuritySnapshot` |
| `Audits.swift` | ~155 | `StorageAuditor` (folder sizes) and `StartupAuditor` (launch items) |
| `PrivacyAudits.swift` | ~107 | Safari / Chrome / Firefox caches and Mail Downloads |
| `DeveloperAudits.swift` | ~108 | Xcode, Docker, package-manager leftovers |
| `ImageAudits.swift` | ~183 | Rotation-tolerant similar images |
| `Uninstaller.swift` | ~174 | App + residue plan, bundle-id validation, its own allow-list |
| `Activity.swift` | ~55 | `ActivityStore` — local JSON history of freed space |
| `Updater.swift` | ~29 | Sparkle wrapper, compiled only under `canImport(Sparkle)` |
| `ModernContentView.swift` | ~1630 | Every screen. The one file that is too big: split it by module when you touch a screen |
| `Theme.swift` | ~690 | Colour tokens, glass panel, 3D pointer card, aurora background, gauges, storage bar |
| `CosmicOrb3DView.swift` | ~420 | SceneKit orb, `reduceMotion` aware |
| `MacClairMCP/main.swift` | ~160 | MCP: `scan_downloads`, `scan_cleanup`, `prepare_trash`, `move_to_trash` (token + exact path + native alert) |
| `MacClairSnapshot/main.swift` | ~? | Renders README screenshots from inside the built bundle |

## What the safety gate actually checks

`SafeTrash.checkLocation` resolves symlinks and refuses anything whose real path is not under
`~/Downloads`, then rejects any path component that:

- starts with `.` (hidden folder),
- is `node_modules`, `Pods`, `DerivedData` or `venv`,
- has an extension in `app`, `bundle`, `framework`, `xcassets`, `xcodeproj`, `xcworkspace`.

`capture` then records `st_size`, `st_mtimespec` (seconds **and** nanoseconds), `st_dev` and
`st_ino`. `validate` re-reads them and throws `.changed` if any differs — a file edited between the
scan and the click is never moved. That is deliberate: it is also why the gate cannot be replaced by
"just move the URL".

## Limits and honesty

| Limit | Value | Where |
|---|---|---|
| Files per cleanup category | 20,000 | `Cleaner.maximumItemsPerCategory` |
| Large-file candidates | 10,000 files / 80,000 entries | `InsightScanner` |
| Duplicate scan | skips hidden folders, packages, project folders | `Insights.swift` |
| Folder walk | does not follow symlinks | all auditors |

When a limit is hit, the report sets `stoppedAtLimit` / `limited` and the UI says so. Never trade
that flag for a cleaner-looking result.

## Adding a new audit

1. New file `Sources/MacClair/<Name>Audits.swift` with an `XxxAuditor` struct exposing
   `scan() -> XxxReport`. Read-only, no `removeItem`, no network.
2. `Tests/<Name>AuditsSmoke.swift` — `@main struct`, temporary directories only, and add both the
   suite name and its source file to the loop in `test.sh` and to `ci.yml` (it calls `test.sh`).
3. UI: a view in `ModernContentView.swift` fed by the report, with counts, sizes and the paths that
   could not be read.
4. Moves, if any, go through `SafeTrash` — never a direct file operation.
5. New UI strings: French source string as the key, translation in `Resources/en.lproj`.

## Localisation

`Resources/en.lproj/Localizable.strings` maps the French source text used in the views to English;
French is the development language. `MacClairApp` resolves the active `Locale` from
`@AppStorage("macclair.language")` (`auto` / `fr` / `en`) and injects it as
`.environment(\.locale, …)`. Adding a language therefore touches three places: a new `.lproj`, the
`Langue / Language` menu, and `CFBundleLocalizations` in `build-app.sh`. Details:
[TRANSLATING.md](TRANSLATING.md).

## Release path

`release-notarized.yml` (`workflow_dispatch` with a version, or a `v*` tag): build on `macos-14` with
`MACCLAIR_ARCHS="arm64 x86_64"` (universal — both slices asserted with `lipo -archs` before anything
is signed), Developer ID sign (including the nested Sparkle binaries), notarize the app **and** the DMG, staple
both, verify with `spctl`, publish `MacClair-<version>-macOS-universal.zip` + `.dmg` + `SHA256SUMS`, then regenerate `docs/appcast.xml` with
Sparkle's `sign_update` and commit it through the contents API. The Homebrew tap
(`n-khd/homebrew-tap`) bumps itself daily from `releases/latest`.

The app binary and `macclair-mcp` are each compiled once per architecture and merged with `lipo`, so a
contributor on an Intel Mac builds and tests exactly what ships.
