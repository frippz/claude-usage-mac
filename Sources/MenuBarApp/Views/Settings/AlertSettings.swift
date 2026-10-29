import SwiftUI

struct AlertSettings: View {
    @AppStorage(SettingsKey.notifyThreshold) private var notifyThreshold = true
    @AppStorage(SettingsKey.warn) private var warn = 50.0
    @AppStorage(SettingsKey.critical) private var critical = 80.0

    var body: some View {
        Form {
            Section {
                Toggle("Notify when a limit crosses a threshold", isOn: $notifyThreshold)
                Text("Once per crossing, at \(Int(warn))% and again at \(Int(critical))% — the same thresholds that colour the rings, set under Display. A window resetting re-arms it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Limits")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
