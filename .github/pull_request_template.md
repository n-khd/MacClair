## What this changes

<!-- One or two sentences. Link the issue: "Closes #123" / "Fixes #123". -->

## Why

<!-- The problem or need. Skip if the linked issue says it. -->

## How you tested it

- [ ] `./test.sh` passes
- [ ] `./build-app.sh` succeeds and `dist/MacClair.app` runs
- [ ] Added or updated a smoke test when behaviour changed

<!-- Describe the manual check: macOS version, Mac type, what you clicked. -->

## Safety

<!-- MacClair never deletes for good: everything goes through the Trash. -->

- [ ] This PR does not widen what can be deleted (still `~/Downloads`, regular files, explicit confirmation)
- [ ] Scans stay read-only
- [ ] No new network call, no telemetry, no analytics

If any box is unticked, explain why in the paragraph above.

## User-visible text

- [ ] New French source strings are added to `Resources/en.lproj/Localizable.strings`
- [ ] Screenshot attached for a UI change (before / after)
