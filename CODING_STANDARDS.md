# Coding standards

The rules for writing and reviewing code and documentation in this
repository. The `code-review` Standards axis checks changes against this file,
and its Bugs axis reads
[What a defect looks like here](#what-a-defect-looks-like-here).
Code and documentation follow the [Simple and lean](AGENTS.md#principle)
principle.

## Writing

Preserve the facts of the source when rewriting or summarising text.

Comments explain why: the constraint, the failure that taught it, the
alternative that was tried. Leave out what the code already says. Match the
density and voice of the comments around the change.

## Documentation

Each topic has one owner: the README what the app does, reads and sends,
the glossary terms, this file how code is written, [AGENTS.md](AGENTS.md)
the workflow, and code and configuration what they do. Other documents link
to the owner instead of repeating it. When an answer changes, rewrite the
owner in place, without a change log; Git history keeps the earlier text. A
change updates the topic's owner and every reference it affects. Refer to a
section by an anchor link to its heading.

Records explain past decisions and are not rewritten to current guidance:
an ADR, an issue or a pull request. How ADRs change is in
[ADR format](.agents/skills/domain-modeling/ADR-FORMAT.md#changing-an-existing-adr).

## Technology and code

- Swift 5.9 language mode, SwiftUI, WidgetKit and AppIntents; the app and
  widget target macOS 14. No third-party dependencies: the package and the
  Xcode project use only Apple frameworks.
- `project.yml` is the project's source; the `.xcodeproj`, the widget's
  `Info.plist` and the entitlements files are generated from it and
  gitignored. Change `project.yml`, never the generated files.
- `UsageCore` holds everything without UI: credentials, the API client,
  profiles, snapshots and formatting. It builds and tests with plain
  `swift build` and `swift test`, so keep AppKit, SwiftUI and WidgetKit out
  of it. `SharedViews` holds views both the app and the widget draw.
- The widget reads `bundle.json` from the App Group container and nothing
  else. Every fetch, credential read and decision happens in the app.
- Keep views free of WidgetKit types where the snapshot tests render them,
  as `Face` does, so they render without linking an app extension.
- Read settings through `@AppStorage` with a key from `SettingsKeys.swift`;
  a key is never renamed once shipped, because stored defaults keep the old
  name.

## What a defect looks like here

Besides code that does the wrong thing, review looks first for these:

- An OAuth token, or anything read from a credentials file or the Keychain,
  reaches a log, an error message, `bundle.json`, the widget or the CLI's
  output.
- Anything writes to a Claude Code config folder, its `.credentials.json` or
  its Keychain item. Credentials are read-only; see the
  [README](README.md#what-it-reads).
- A network request other than the one usage request in `UsageAPI`, or a
  User-Agent that is not the app's own.
- The widget extension reaches the network, credentials or files outside its
  App Group container, or loses its sandbox entitlement.
- A widget kind, the App Group name, a bundle identifier or a parameter
  type of `UsageConfigIntent` changes. WidgetKit cannot migrate placed
  widgets across any of these; they go blank. Adding a parameter is safe.
- WidgetKit reloads when nothing it draws changed, which spends the
  system's reload budget; see `SnapshotBundle.draws(differentlyFrom:)`.
- Work that can block, such as the Keychain read waiting on a consent
  dialog, runs on the main thread.
- A test is removed or skipped, or an assertion is changed to match new
  behaviour, when neither the request asks for it nor the pull request gives
  a reason.

## Interface and accessibility

- Status never depends on colour alone: a level also shows as text, a
  symbol or a shape, as the menu bar's text style shows critical with `!`.
- Text and gauges keep their contrast in both light and dark mode; the
  [rendered check](AGENTS.md#verification-and-handoff) covers both.
- Every control has an accessibility label VoiceOver can read, and a gauge
  reads as its value ("Five-hour limit, 42 percent"), not as a picture.
- Use system controls and SF Symbols before custom drawing, and keep the
  menu bar image a template unless the user chose a colour mode.
- Copy names the action and says what to do next, as "Token expired — open
  Claude Code in this profile" does.
