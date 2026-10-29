# Translating MacClair

The interface ships in **French** (the development language) and **English**. Adding a language
does not require Swift: it is one `.strings` file plus three small edits.

Coverage today:

| Language | Code | File | Status |
|---|---|---|---|
| French | `fr` | *(source strings in the code)* | complete |
| English | `en` | `Resources/en.lproj/Localizable.strings` | complete |
| any other | `de`, `es`, `nl`, `it`, `pt-BR`, … | `Resources/<code>.lproj/Localizable.strings` | wanted |

## How the strings work

Every UI string is written in French **in the Swift code**, and that French text *is* the lookup
key. `Resources/en.lproj/Localizable.strings` maps it to English:

```
"Fichiers inutiles" = "Unneeded files";
```

So a translator never touches the Swift files: copy the English file, keep every key exactly as it
is, and translate only the right-hand side.

## Steps

```sh
cd MacClair
cp -R Resources/en.lproj Resources/de.lproj            # de = your language code
$EDITOR Resources/de.lproj/Localizable.strings
```

Then three edits so the app can actually pick the language:

1. `build-app.sh` — add the code to `CFBundleLocalizations`:
   `<string>fr</string><string>en</string><string>de</string>`
2. `Sources/MacClair/MacClairApp.swift` — `activeLocale`: add `case "de": return Locale(identifier: "de")`
   and extend the fallback so a German system does not fall back to French
   (`preferred.hasPrefix("de") ? "de" : …`).
3. Same file, the `Langue / Language` menu: add `Text("Deutsch").tag("de")`.

Test it: `./build-app.sh`, `open dist/MacClair.app`, then **MacClair › Langue / Language › Deutsch**
and walk through every screen. For the README screenshots, run the **Captures d'écran** workflow
(`screenshots.yml`, `workflow_dispatch` from the Actions tab) — it renders the app in every language
from the bundle.

## Rules

- **Never change a key.** `"VUE D’ENSEMBLE" = …` — the left side must stay byte-identical, including
  the typographic apostrophe `’` (U+2019) and capital letters. A changed key silently falls back to
  French.
- **Keep placeholders untouched:** `%lld`, `%@`, `%d`. You may reorder them only if you use `%1$@`
  style positionals consistently, and `%lld` must stay an integer format.
- **Keep the file valid:** UTF-8, one `"key" = "value";` per line, semicolons, trailing `;`. A missing
  semicolon breaks the whole file, not just one line.
- **Do not translate:** `MacClair`, file paths, bundle identifiers, extensions (`dmg`, `app`),
  keyboard symbols (`⌘`), and the French technical terms used verbatim in macOS (`Corbeille` is
  translated, `~/Downloads` is not).
- **Watch the layout.** Sidebar labels and buttons are narrow: prefer short words, and check a screen
  with long words (German compounds) before opening the PR.
- **Tone:** plain, factual, no exclamation marks, no marketing. The app tells you what it will do
  before it does it — the translation must keep that promise ("Déplacer vers la Corbeille", not
  "Nettoyer maintenant").

## Opening the PR

```
i18n: add German translation
```

Include a screenshot of one screen in your language, and mention whether you are a native speaker.
If you would rather not open a pull request, attach the translated `.strings` file to an issue using
the *Traduction / Translation* template — someone will wire it up and credit you in the CHANGELOG.
