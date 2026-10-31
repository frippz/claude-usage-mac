import AppIntents
import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    let scopeLabel: String?
    /// Set when the widget's configuration could not be honoured. Rendered
    /// instead of numbers, because showing some other account's figures under
    /// this widget's name is worse than showing nothing.
    var problem: WidgetProblem?
}

struct UsageProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .preview, scopeLabel: nil)
    }

    func snapshot(for configuration: UsageConfigIntent, in context: Context) async -> UsageEntry {
        // The widget gallery shows this, and it must look populated there even
        // when the host app has never run.
        context.isPreview ? placeholder(in: context) : entry(for: configuration)
    }

    func timeline(for configuration: UsageConfigIntent, in context: Context) async -> Timeline<UsageEntry> {
        // The host app pushes reloads as it polls, which is the real update path.
        // This is only the fallback for when it isn't running.
        Timeline(entries: [entry(for: configuration)],
                 policy: .after(Date().addingTimeInterval(delay(for: configuration))))
    }

    /// This widget's own choice, else whatever the app says it polls at, else
    /// fifteen minutes.
    ///
    /// ponytail: floored at five minutes, and that floor is why the picker starts
    /// there. WidgetKit budgets macOS reloads and quietly ignores anything
    /// tighter, so offering a minute would be a control that lies.
    private func delay(for configuration: UsageConfigIntent) -> TimeInterval {
        let chosen = RefreshOptions.choices
            .first { $0.label == configuration.refresh }?.seconds ?? 0
        guard chosen == 0 else { return chosen }

        let app = SnapshotBundle.read()?.refreshSeconds
        return max(300, TimeInterval(app ?? 900))
    }

    private func entry(for configuration: UsageConfigIntent) -> UsageEntry {
        // Empty strings can come back from a cleared picker; treat them as unset.
        let wantedProfile = configuration.profile.flatMap { $0.isEmpty ? nil : $0 }

        guard let bundle = SnapshotBundle.read() else {
            return UsageEntry(date: Date(), snapshot: nil, scopeLabel: nil, problem: .noData)
        }

        let profile: Profile?
        let snapshot: Snapshot?
        if let wantedProfile {
            guard let match = bundle.snapshot(forExactly: wantedProfile) else {
                // Configured for an account this bundle doesn't have — the
                // folder moved, or was removed in Settings.
                return UsageEntry(date: Date(), snapshot: nil,
                                  scopeLabel: bundle.profile(forExactly: wantedProfile)?.displayName
                                      ?? (wantedProfile as NSString).lastPathComponent,
                                  problem: .profileMissing)
            }
            profile = bundle.profile(forExactly: wantedProfile)
            snapshot = match
        } else {
            profile = bundle.defaultProfile
            snapshot = bundle.defaultSnapshot
        }

        let showsProfile = bundle.profileList.count > 1
        return UsageEntry(date: Date(), snapshot: snapshot,
                          scopeLabel: showsProfile ? profile?.displayName : nil)
    }
}

struct UsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        UsageWidgetView(snapshot: entry.snapshot,
                        scopeLabel: entry.scopeLabel,
                        problem: entry.problem,
                        face: Face(family))
            .containerBackground(for: .widget) { Rectangle().fill(.fill.tertiary) }
    }
}

// The kind string and the configuration type are frozen the moment a widget is
// placed: WidgetKit has no supported migration for either, and changing a
// parameter's *type* silently empties every placed widget's choice. Adding a
// parameter is safe — it simply arrives nil.
@main
struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "se.frodlund.claude-usage.widget",
                               intent: UsageConfigIntent.self,
                               provider: UsageProvider()) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Headroom")
        .description("Five-hour and weekly limits.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

extension Face {
    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemLarge: self = .large
        default:           self = .medium
        }
    }
}
