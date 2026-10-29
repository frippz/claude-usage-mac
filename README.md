# claude-usage-mac

Claude Code's five-hour and weekly usage limits in the macOS menu bar and as a
desktop widget.

A personal fork of [saeedkolivand/claude-usage-mac](https://github.com/saeedkolivand/claude-usage-mac),
cut down to the limits alone. It has no updater, never writes Claude Code's
credentials, and does not read your transcripts.

## Build and install

Requires macOS 14 or later, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
./build.sh               # build, install to /Applications, launch
./build.sh --no-install  # build only, into .build-xcode
```

There are no releases. Build it yourself.

Both targets are signed with an Apple Development certificate from team
`XU3G5KB593`, which is mine. To build under your own team, change the team ID
in `project.yml` (`DEVELOPMENT_TEAM` and both App Group entitlements) and in
`SnapshotBundle.appGroup`. A free Personal Team works: the App Group is
team-prefixed, so it needs no provisioning profile.

The widget appears in the widget gallery once the app has run.

## What it reads

| Source | Used for |
|---|---|
| The OAuth access token Claude Code already stored | Authenticating the request below |
| `api.anthropic.com/api/oauth/usage` | Five-hour and seven-day utilization, per-model weekly windows where the plan has them, and when each resets |

That request is the only thing sent anywhere. It identifies itself honestly as
`claude-usage-mac/<version>`. The endpoint is undocumented and may change or
disappear without notice; if it does, the app shows an error rather than
numbers.

The token is read from `<config dir>/.credentials.json`, falling back to the
login Keychain. Claude Code names the Keychain item after its config folder:
`Claude Code-credentials` for `~/.claude`, and
`Claude Code-credentials-<first 8 hex of sha256(config dir)>` for a folder
relocated with `CLAUDE_CONFIG_DIR`.

The Keychain is read directly, so macOS asks once whether Claude Usage may use
the item. "Always Allow" covers later rebuilds signed with the same certificate.

**Tokens are read-only.** The app never refreshes or writes a token. Refreshing
would use up Claude Code's single-use refresh token behind its back and could log
it out. When the access token expires, the app says "Token expired — open Claude
Code in this profile" until Claude Code refreshes it.

The burn rate is measured, not reported: percentage points per hour across the
app's own readings of the five-hour window. It shows nothing until a couple of
polls of active use have gone by.

## Profiles

A profile is a Claude Code config folder, which means one logged-in account.
Discovery looks at `~/.claude`, at any folder beside it whose name starts with
`.claude`, and at folders you add in Settings. A folder counts if it contains a
`projects` directory.

Pick the menu bar's profile in Settings. Each widget picks its own in Edit
Widget.

The Keychain item's name is hashed from the literal `CLAUDE_CONFIG_DIR` string
you exported. Claude Code doesn't resolve the path, so `~/.claude-work` and
`/Users/you/.claude-work/` are different items. The app tries the likely
spellings. If yours is unusual, the profile reports `no-token`. Settings → Profiles
shows the name it looks for.

## Settings

| Tab | What's there |
|---|---|
| General | Refresh interval, open at login, global shortcut |
| Display | Menu bar style and colour, which limit it shows, amber and red thresholds |
| Alerts | Notifications when a limit crosses a threshold |
| Profiles | Which account the menu bar shows, extra folders, rescan |

Numbers are marked outdated after three missed polls, whatever the interval.

## How it fits together

- **`UsageCore`**: a Swift package holding credentials, the API client,
  profiles, snapshots and formatting. It has no UI.
- **`Claude Usage.app`**: the menu bar app. It polls every profile and writes
  one `bundle.json`, readable only by you, to the App Group container
  `XU3G5KB593.se.frodlund.claude-usage`. Then it asks WidgetKit to reload.
- **`ClaudeUsageWidget.appex`**: the sandboxed widget. It reads that file and
  nothing else, and never touches the network or credentials.
- **`usage-cli`**: a read-only command-line view of the same data.

## Development

```sh
swift test                       # unit tests
swift run usage-cli              # human-readable summary
swift run usage-cli --profiles   # discovered profiles
swift run usage-cli --json       # what the widget will render
```

`usage-cli` is unsigned, so macOS asks for Keychain access again after each
rebuild.

The snapshot tests render every widget size and the menu popover to PNGs in
`snapshots/`:

```sh
xcodegen generate
xcodebuild test -project ClaudeUsage.xcodeproj -scheme SnapshotTests
```

## License

MIT, see [LICENSE](LICENSE). The original work is by Saeed Kolivand. Upstream
declares MIT in its README but ships no license file, so this one uses the
standard MIT text.
