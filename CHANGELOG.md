# Changelog

All notable changes to MacClair. Dates are release dates (Europe/Brussels).

## Unreleased

- Contribution layer: `CONTRIBUTING.md` and `CONTRIBUTING.fr.md` (first pull request in 20 minutes,
  code map, the six safety rules, build troubleshooting), plus `docs/ARCHITECTURE.md` and
  `docs/TRANSLATING.md` for adding a language with a single file.
- GitHub housekeeping: pull request template, code of conduct, bilingual issue forms, a translation
  form, Discussions and private security links, a pinned “Start here” issue and a `good first issue`
  backlog covering translation, VoiceOver, shortcuts, sorting, the MCP smoke test, a universal build
  and the appcast check.

## 0.8.0 — 2026-10-28

- Interface available in **French and English**, following the macOS language by default,
  with a manual override in **MacClair › Langue / Language**.
- `README.md` in English, French version kept in `README.fr.md`; release notes in English.
- Release notes and Homebrew cask description now in English for the international audience.

## 0.7.0 — 2026-10-28

- New interface: design system (`Theme.swift`), interactive 3D core (`CosmicOrb3DView.swift`),
  activity history, uninstaller with leftovers, developer and privacy audits.
- Local **MCP server** (`macclair-mcp`) bundled in the app: read-only scans plus a guarded
  `move_to_trash` (prepared token + exact confirmed path + native confirmation).
- Security: bundle identifier validation and containment when planning an uninstall, so a crafted
  `../Keychains` identifier can no longer reach the user keychain; sensitive folders
  (`~/Library/Keychains`, `Messages`, `Mail`, `Safari`, `Cookies`, `Accounts`) are refused.
- MCP tool schemas validated by tests (annotations, required fields).

## 0.6.2 — 2026-10-28

- Repository moved to the `n-khd` GitHub account: Sparkle feed, Homebrew tap and release URLs updated.
- Installed apps receive the new feed in a single update.

## 0.6.1 — 2026-10-28

- No code change: published to prove the self-update path (0.6.0 → 0.6.1) end to end.

## 0.6.0 — 2026-10-28

- **Automatic updates** through Sparkle: EdDSA-signed `appcast.xml`, generated and published by CI.
- `Sparkle.framework` re-signed with the Developer ID identity so notarization accepts the nested
  helpers.

## 0.5.2 — 2026-10-28

- Signed, notarized and stapled **DMG** in addition to the zip.
- **Homebrew cask** published in the `n-khd/homebrew-tap` tap, updated automatically from releases.

## 0.5.1 — 2026-10-28

- First **notarized** release (Developer ID certificate, Apple notary service, stapled ticket).
- No more Gatekeeper warning on first launch.

## 0.5.0 — 2026-10-28

- First public release: storage overview, unneeded files, large files, exact duplicates,
  similar images, telescope view, Trash-only moves limited to `~/Downloads`.
