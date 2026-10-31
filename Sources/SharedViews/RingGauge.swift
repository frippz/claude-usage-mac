import SwiftUI

/// The percentage ring. Same shape at every size — only `lineWidth` and the
/// font scale change between the menu bar popover and the three widget families.
struct RingGauge: View {
    let pct: Double?
    let level: Level
    var lineWidth: CGFloat = 8
    var showsPercent = true
    /// Overrides the threshold tint: the menu bar's mono and custom colour
    /// modes, and grey for outdated numbers. Nil keeps `level.tint`.
    var tint: Color?

    private var color: Color { tint ?? level.tint }

    private var fraction: CGFloat {
        guard let pct else { return 0 }
        return CGFloat(min(max(pct / 100, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            // Apple's widget rings run ~8-10% of their diameter. `lineWidth` is
            // a ceiling, not a promise: when a layout squeezes the ring (the
            // large face after the THIS MAC label landed), the stroke thins
            // with it instead of turning the ring into a donut.
            let stroke = min(lineWidth, side * 0.09)
            ZStack {
                // Strokes straddle the path, so without this inset the outer half
                // spills past the frame and gets clipped by the container.
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: stroke)
                    .padding(stroke / 2)
                if pct != nil {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(color,
                                style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(stroke / 2)
                }
                if showsPercent {
                    Text(Format.percent(pct))
                        // Scales with the ring so one view serves every widget family.
                        .font(.system(size: side * 0.28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(pct == nil ? Level.none.tint : .primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A ring with its metric name and reset countdown underneath.
struct MetricGauge: View {
    let snapshot: Snapshot
    let metric: Metric
    var lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            RingGauge(pct: snapshot.pct(metric),
                      level: snapshot.level(metric),
                      lineWidth: lineWidth,
                      tint: snapshot.stale ? Level.none.tint : nil)
            VStack(spacing: 1) {
                MetricLabel(snapshot: snapshot, metric: metric)
                Text(snapshot.resetsText(metric))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(snapshot.spokenValue(metric))
    }
}

/// A metric's caption, with its level's symbol beside it.
struct MetricLabel: View {
    let snapshot: Snapshot
    let metric: Metric
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 3) {
            Text(metric.label)
                .font(.system(size: size, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            if let symbol = snapshot.level(metric).symbol {
                Image(systemName: symbol)
                    .font(.system(size: size - 1))
                    .foregroundStyle(snapshot.stale ? Level.none.tint : snapshot.level(metric).tint)
            }
        }
    }
}

/// The one bar shape in the app: a tinted capsule over its own faded track.
/// Three views drew this separately before it was worth naming.
struct MiniBar: View {
    let fraction: Double
    var tint: Color = Level.ok.tint
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule().fill(tint)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// A per-model weekly window as one line.
///
/// Not a ring: these only exist on some plans, so the layout has to survive them
/// being absent, and two more rings would not fit the popover or any widget
/// family below large.
struct LimitRow: View {
    let snapshot: Snapshot
    let metric: Metric

    var body: some View {
        HStack(spacing: 8) {
            MetricLabel(snapshot: snapshot, metric: metric)
                .frame(width: 60, alignment: .leading)
            MiniBar(fraction: (snapshot.pct(metric) ?? 0) / 100,
                    tint: snapshot.stale ? Level.none.tint : snapshot.level(metric).tint,
                    height: 4)
            Text(Format.percent(snapshot.pct(metric)))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
            Text(snapshot.resetsText(metric))
                .font(.system(size: 9))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(snapshot.spokenValue(metric))
    }
}

extension Snapshot {
    /// Placeholder for widget galleries and snapshot tests.
    static var preview: Snapshot {
        var snapshot = Snapshot(
            usage: UsageData(
                fiveHour: UsageNode(utilization: 42,
                                    resetsAt: Date().addingTimeInterval(2 * 3600 + 14 * 60)),
                sevenDay: UsageNode(utilization: 18,
                                    resetsAt: Date().addingTimeInterval(4 * 86400 + 6 * 3600)),
                sevenDayOpus: UsageNode(utilization: 61,
                                        resetsAt: Date().addingTimeInterval(4 * 86400 + 6 * 3600)),
                sevenDaySonnet: UsageNode(utilization: 12,
                                          resetsAt: Date().addingTimeInterval(4 * 86400 + 6 * 3600))))
        snapshot.burnRatePerHour = 9
        return snapshot
    }

    /// The same account on a plan with no per-model windows and no measured burn
    /// rate — the majority case, and the one the layout has to survive.
    static var previewPlain: Snapshot {
        var snapshot = preview
        snapshot.opusPct = nil
        snapshot.opusResetsAt = nil
        snapshot.sonnetPct = nil
        snapshot.sonnetResetsAt = nil
        snapshot.burnRatePerHour = nil
        return snapshot
    }
}
