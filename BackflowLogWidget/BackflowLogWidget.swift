import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct BackflowLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Overdue").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.overdueCount)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(snapshot.overdueCount > 0 ? Color.red : Color.primary)
                Text("assemblies").font(.caption).foregroundStyle(.secondary)
            }
            Text("\(snapshot.dueSoonCount) due soon")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if snapshot.gaugeOutOfCalibration {
                Label("Gauge calibration expired", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if snapshot.neverTestedCount > 0 {
                Label("\(snapshot.neverTestedCount) never tested", systemImage: "questionmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .lineLimit(1)
            }
            if family != .systemSmall, !snapshot.nextName.isEmpty {
                Divider()
                Text(snapshot.nextName).font(.footnote.weight(.semibold)).lineLimit(1)
                if let days = snapshot.nextDays {
                    Text(Formatters.due(days)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct BackflowLogWidget: Widget {
    let kind = "BackflowLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            BackflowLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("What is overdue on your route.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BackflowLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BackflowLogWidget()
    }
}
