# Contributing to MacClair

Thanks for being here. MacClair is a small macOS app — about 4,400 lines of Swift, no
dependencies, one build script — so there is no week-long ramp-up. You can change something
real in your first hour.

**Français :** [CONTRIBUTING.fr.md](CONTRIBUTING.fr.md).

New here? Pick an issue labelled [`good first issue`](https://github.com/n-khd/MacClair/labels/good%20first%20issue)
and say hello in it. Nobody will be annoyed that you asked.

## Ways to help, in order of usefulness

1. **Translate.** The interface already ships in French and English; a third language is mostly
   one file. See [docs/TRANSLATING.md](docs/TRANSLATING.md). No Swift needed.
2. **Report reproducible bugs.** A version, a macOS version, and the three clicks that trigger it
   are worth more than a paragraph of prose. Use the issue template.
3. **Test on your machine.** A Mac on macOS 15, an Intel Mac, a non-admin account, a disk with
   weird permissions — these are cases the maintainer cannot run alone.
4. **Write code.** Filters, sorting, tests, accessibility, performance on big folders.
5. **Improve the docs.** If a sentence in this file confused you, it will confuse the next person.

## First pull request in 20 minutes

```sh
# 1. Get the code
gh repo clone n-khd/MacClair    # or git clone https://github.com/n-khd/MacClair.git
cd MacClair

# 2. Build and run the tests (macOS 14+, Xcode or the Command Line Tools with Swift 6)
./test.sh                 # smoke tests for the scanner, trash safety, audits, MCP helper
./build-app.sh            # produces dist/MacClair.app
open dist/MacClair.app

# 3. Branch, change, test, push
git checkout -b fix/duplicates-hidden-folders
./test.sh
git commit -m "fix: skip hidden folders when grouping duplicates"
gh pr create --fill      # or open the PR in the browser
```

The local build is signed ad hoc and has no Sparkle updater — that is expected. CI will build and
test your branch on `macos-14`; a red CI is a blocker, a green CI does not replace reading the diff.

## What CI runs

`.github/workflows/ci.yml`, on every pull request:

| Step | Command | What a failure means |
|---|---|---|
| Smoke tests | `./test.sh` | A scanner, trash-safety, audit or MCP test regressed |
| Compile | `./build-app.sh` | The app does not build on a clean macOS runner |

`compile-check.yml` compiles the sources on other configurations; `screenshots.yml` regenerates
the documentation screenshots — you do not need to run either.

## Project layout

| Path | Role |
|---|---|
| `Sources/MacClair/Scanner.swift` | Inventory of caches, logs and old installers; `Cleaner` runs it and moves items |
| `Sources/MacClair/SafeTrash.swift` | The safety gate. Every move to the Trash goes through `capture` → `validate` → `moveToTrash` |
| `Sources/MacClair/Insights.swift` | Large files, duplicates, installed apps, system and security snapshots |
| `Sources/MacClair/Audits.swift` | Storage breakdown and launch items — read-only |
| `Sources/MacClair/PrivacyAudits.swift` | Safari / Chrome / Firefox caches, Mail Downloads — read-only |
| `Sources/MacClair/DeveloperAudits.swift` | Xcode, Docker and package-manager leftovers |
| `Sources/MacClair/ImageAudits.swift` | Rotation-tolerant similar-image detection |
| `Sources/MacClair/Uninstaller.swift` | App + residue planner and its own allow-list |
| `Sources/MacClair/ModernContentView.swift` | The whole interface (SwiftUI) |
| `Sources/MacClair/Theme.swift` | Colours, panels, gauges, buttons — the design system |
| `Sources/MacClair/CosmicOrb3DView.swift` | The SceneKit orb |
| `Sources/MacClair/Activity.swift` | Local history of what was moved and how much space it freed |
| `Sources/MacClair/Updater.swift` | Sparkle; compiled in only when the framework is present |
| `Sources/MacClairMCP/main.swift` | Bundled MCP server (stdio JSON-RPC) |
| `Sources/MacClairSnapshot/main.swift` | Renders the screenshots used in the READMEs |

More detail, including the data flow and the invariants that must hold: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Rules that are not negotiable

These are the product, not implementation details. A pull request that breaks one of them will be
asked to change, even if the feature is nice.

1. **Nothing is deleted for good.** Every file leaves through the macOS Trash, via `SafeTrash`.
2. **Moves stay inside `~/Downloads`** and only touch regular files. Symbolic links, hidden
   folders, packages (`*.app`), Git internals and anything outside that scope are refused.
3. **The user confirms.** No background or automatic cleaning, ever. The MCP server may only move
   a file after a prepared token *and* the exact path the user confirmed.
4. **Read-only scans.** An inventory may report and refuse; it must never mutate what it reads.
5. **No network, no telemetry, no account.** The only outbound request in the whole app is the
   signed Sparkle update check.
6. **Errors are surfaced, not swallowed.** A folder that cannot be read is reported in the UI with
   its path — partial results are labelled as partial.

## Coding conventions

- Swift 6 toolchain, compiled with `-swift-version 5`; the app target is `macOS 14+`. Keep it
  dependency-free: no SwiftPM package is added without an issue first.
- **Localisation:** French source strings are the keys. When you add UI text, add the pair to
  `Resources/en.lproj/Localizable.strings`. Never translate paths, bundle identifiers or file names.
- **Tests are plain executables**, not XCTest: `Tests/<Suite>Smoke.swift` with a `@main struct`
  that throws on failure, compiled by the loop in `test.sh`. To add a suite, add the file and one
  line to that loop. Use temporary directories — never a real home folder.
- Prefer small, typed values (`CleanupItem`, `TrashCandidate`) over dictionaries and tuples.
- Comments explain *why* (a safety check, a macOS quirk), not *what* the next line does.

## Commits and pull requests

- Branch names: `fix/…`, `feat/…`, `docs/…`, `i18n/…`.
- Commit messages: `fix: …`, `feat: …`, `docs: …`, `i18n: …`, one logical change per commit.
  French or English, both are fine.
- One pull request = one subject. Unrelated clean-ups belong in another PR.
- Fill in the pull request template: what changed, how you tested it, and the safety checklist.
- No CLA, no copyright assignment. Your contribution is published under the MIT licence and you
  keep the credit.

## Review

The maintainer reviews on a best-effort basis, usually within a week. You may get "not now" or
"not in scope" — that is about the product's focus (see [ROADMAP.md](ROADMAP.md)), not about your
work. If a PR sits unanswered for two weeks, comment in it; that is not rude, it is useful.

## Security and conduct

- Vulnerability: follow [SECURITY.md](SECURITY.md) — never a public issue.
- Behaviour: [CODE_OF_CONDUCT.md](.github/CODE_OF_CONDUCT.md).
- Questions and open-ended ideas: [Discussions](https://github.com/n-khd/MacClair/discussions).
