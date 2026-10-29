import Foundation

/// Severity band for a utilization percentage. Lives here rather than in the
/// views so both the menu bar and the widget colour identically, and so
/// UsageCore stays free of SwiftUI.
public enum Level: String, Sendable {
    case none    // no data
    case ok
    case warn
    case critical

    public static func of(_ pct: Double?, warn: Double = 50, critical: Double = 80) -> Level {
        guard let pct else { return .none }
        if pct >= critical { return .critical }
        if pct >= warn { return .warn }
        return .ok
    }
}

public enum Format {

    /// "4d 6h" / "2h 14m" / "45m" / "" when unknown. Clamps at zero rather than
    /// counting up past a reset we haven't refreshed through yet.
    public static func until(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        var seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86400
        seconds -= days * 86400
        let hours = seconds / 3600
        seconds -= hours * 3600
        let minutes = seconds / 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    public static func percent(_ pct: Double?) -> String {
        guard let pct else { return "--" }
        return "\(Int(pct.rounded()))%"
    }

}

public enum HexColor {
    /// "#22c55e", "22c55e" or "#2c5" to components in 0...1. Nil when malformed,
    /// so callers can fall back to the threshold tint rather than guess.
    ///
    /// Lives here rather than in the views because parsing is pure string work,
    /// and this is the layer `swift test` reaches.
    public static func rgb(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, s.allSatisfy(\.isHexDigit), let v = UInt32(s, radix: 16)
        else { return nil }
        return (Double((v >> 16) & 0xff) / 255,
                Double((v >> 8) & 0xff) / 255,
                Double(v & 0xff) / 255)
    }
}

public enum AppVersion {
    /// Reads the bundle rather than a constant, so it can't drift from what
    /// xcodebuild actually stamped in.
    public static var current: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}
