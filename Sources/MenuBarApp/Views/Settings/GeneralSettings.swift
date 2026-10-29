import ServiceManagement
import SwiftUI

struct GeneralSettings: View {
    @ObservedObject var poller: Poller

    @AppStorage(SettingsKey.refreshInterval) private var refreshSeconds = 60
    @AppStorage(SettingsKey.hotkey) private var hotkey = HotkeyChoice.off.rawValue
    @AppStorage(SettingsKey.userAgent) private var userAgent = UsageAPI.defaultUserAgent
    /// Read once when the view is first built rather than on every redraw — an
    /// install cannot change source while the app is running.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section {
                Picker("Check usage", selection: $refreshSeconds) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval.rawValue)
                    }
                }
                // End the current wait rather than let it run out: it is a sleep
                // of the old length, so without this a change from ten minutes
                // to one would take ten minutes to happen.
                .onChange(of: refreshSeconds) { _, _ in poller.wakeNow() }
                Text("Every profile is polled on this schedule, and each poll is what refreshes the widgets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
                Picker("Global shortcut", selection: $hotkey) {
                    ForEach(HotkeyChoice.allCases) { choice in
                        Text(choice.label).tag(choice.rawValue)
                    }
                }
                .onChange(of: hotkey) { _, new in
                    HotkeyManager.shared.apply(HotkeyChoice(rawValue: new) ?? .off)
                }
                Text("Opens the menu from anywhere. If another app already owns the combination, this one silently loses it — pick a different one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("User-Agent", text: $userAgent)
                Text("The usage endpoint rate-limits clients that don't identify as Claude Code. Change this only if the version string goes stale.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    // MARK: - Login item

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            // Unsigned builds can't register a login item; say so rather than
            // silently flipping the toggle back.
            launchError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
