import SwiftUI

// Same palette as the Stream Deck plugin, so the two products read identically.
// Ok and warn darken in light mode, where the dark-mode shades fall below the
// 3:1 a gauge needs against white.
extension Level {
    var tint: Color {
        switch self {
        case .none:     return Color(red: 0.42, green: 0.45, blue: 0.50)  // #6b7280
        case .ok:       return .scheme(light: 0x16a34a, dark: 0x22c55e)
        case .warn:     return .scheme(light: 0xd97706, dark: 0xf59e0b)
        case .critical: return Color(red: 0.94, green: 0.27, blue: 0.27)  // #ef4444
        }
    }

    /// Shown beside the tint, so warn and critical never rest on colour alone.
    var symbol: String? {
        switch self {
        case .none, .ok: return nil
        case .warn:      return "exclamationmark.triangle.fill"
        case .critical:  return "exclamationmark.octagon.fill"
        }
    }

    /// What VoiceOver adds after the percentage.
    var spoken: String? {
        switch self {
        case .none, .ok: return nil
        case .warn:      return "warn level"
        case .critical:  return "critical level"
        }
    }
}

private extension Color {
    static func scheme(light: Int, dark: Int) -> Color {
        func rgb(_ hex: Int) -> NSColor {
            NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255,
                    green: CGFloat(hex >> 8 & 0xff) / 255,
                    blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        }
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? rgb(dark) : rgb(light)
        })
    }
}

/// Raw values are the stored setting, so a picker tag round-trips without a
/// second mapping table.
enum Metric: String, CaseIterable {
    case session
    case weekly
    case opus
    case sonnet

    var label: String {
        switch self {
        case .session: return "5 HOURS"
        case .weekly:  return "WEEKLY"
        case .opus:    return "OPUS"
        case .sonnet:  return "SONNET"
        }
    }

    /// Sentence case, for notifications and pickers — the all-caps `label` is a
    /// chart heading and reads as shouting anywhere else.
    var title: String {
        switch self {
        case .session: return "5-hour limit"
        case .weekly:  return "Weekly limit"
        case .opus:    return "Opus weekly limit"
        case .sonnet:  return "Sonnet weekly limit"
        }
    }

    /// For the menu bar, where a word costs more room than it earns.
    var initial: String {
        switch self {
        case .session: return "5H"
        case .weekly:  return "W"
        case .opus:    return "O"
        case .sonnet:  return "S"
        }
    }
}

extension Snapshot {
    /// Nil once the window has reset: the stored number belongs to the window
    /// that ended, and the next successful poll brings the real one.
    func pct(_ metric: Metric, now: Date = Date()) -> Double? {
        hasReset(metric, now: now) ? nil : storedPct(metric)
    }

    func hasReset(_ metric: Metric, now: Date = Date()) -> Bool {
        resetsAt(metric).map { $0 <= now } ?? false
    }

    private func storedPct(_ metric: Metric) -> Double? {
        switch metric {
        case .session: return sessionPct
        case .weekly:  return weeklyPct
        case .opus:    return opusPct
        case .sonnet:  return sonnetPct
        }
    }

    func resetsAt(_ metric: Metric) -> Date? {
        switch metric {
        case .session: return sessionResetsAt
        case .weekly:  return weeklyResetsAt
        case .opus:    return opusResetsAt
        case .sonnet:  return sonnetResetsAt
        }
    }

    /// The per-model windows this account actually has. Empty on plans without
    /// them, which is why every caller renders it as a list rather than as two
    /// fixed rows with placeholders.
    var perModelLimits: [Metric] {
        [.opus, .sonnet].filter { storedPct($0) != nil }
    }

    /// Whether any limit was ever fetched. A snapshot without one carries the
    /// poll's own time as `updatedAt`, so that time says nothing.
    var hasNumbers: Bool {
        Metric.allCases.contains { storedPct($0) != nil }
    }

    /// "resets 2h 14m", "just reset" once the window has ended, "—" unknown.
    func resetsText(_ metric: Metric, now: Date = Date()) -> String {
        guard let date = resetsAt(metric) else { return "—" }
        return date <= now ? "just reset" : "resets \(Format.until(date, now: now))"
    }

    /// A limit's VoiceOver value: "42 percent, warn level, resets in 2 hours,
    /// 14 minutes".
    func spokenValue(_ metric: Metric, now: Date = Date()) -> String {
        var parts = [pct(metric, now: now).map { "\(Int($0.rounded())) percent" } ?? "no number"]
        if let spoken = level(metric, now: now).spoken { parts.append(spoken) }
        if let date = resetsAt(metric) {
            parts.append(date <= now
                ? "just reset"
                : "resets in \(Self.spokenDuration.string(from: now, to: date) ?? "")")
        }
        if stale { parts.append("outdated") }
        return parts.joined(separator: ", ")
    }

    private static let spokenDuration: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.day, .hour, .minute]
        f.maximumUnitCount = 2
        return f
    }()

    /// "12%/h · full in 1h 20m", or just the rate when the window resets first.
    /// Nil whenever there is no measured rate — the ordinary case.
    func burnSummary(now: Date = Date()) -> String? {
        guard let rate = burnRatePerHour, rate > 0,
              !hasReset(.session, now: now) else { return nil }
        let head = "\(Int(rate))%/h"
        guard let seconds = timeToFull(now: now) else { return head }
        return "\(head) · full in \(Format.until(now.addingTimeInterval(seconds), now: now))"
    }

    func level(_ metric: Metric, now: Date = Date()) -> Level {
        Level.of(pct(metric, now: now), warn: warn, critical: critical)
    }

    /// Human-readable form of the error codes UsageCore reports.
    var errorMessage: String? {
        switch error {
        case nil:               return nil
        case "no-token":        return "Sign in with Claude Code"
        // Deliberately not refreshed here: only Claude Code writes its own
        // credentials (see UsageAPI.fetch).
        case "token-expired":   return "Token expired — open Claude Code in this profile"
        case "http-401":        return "Token rejected — open Claude Code in this profile"
        case "http-429":        return "Claude is limiting requests — will retry"
        case "network":         return "No connection — check your network"
        case "bad-json":        return "Couldn't read Claude's reply — will retry"
        case _?:                return "Couldn't update — will retry"
        }
    }
}
