import AppIntents
import SwiftUI
import WidgetKit

@main
struct TrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrackWidget()
    }
}

struct TrackWidget: Widget {
    let kind = "TrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TrackWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("TrackMyThings")
        .description("Touchez un événement puis confirmez pour l'enregistrer.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline

struct TrackEntry: TimelineEntry {
    let date: Date
    let data: AppData
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TrackEntry {
        TrackEntry(date: Date(), data: .initial)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackEntry) -> Void) {
        completion(TrackEntry(date: Date(), data: Store.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackEntry>) -> Void) {
        let now = Date()
        let data = Store.load()

        // Moments où l'affichage doit changer : fin de la confirmation en attente,
        // fin du bandeau « enregistré », passage en retard d'un événement.
        var changes: [Date] = []
        if let since = data.pendingSince {
            changes.append(since.addingTimeInterval(AppData.pendingTimeout))
        }
        if let at = data.lastConfirmedAt {
            changes.append(at.addingTimeInterval(AppData.bannerDuration))
        }
        for type in data.types {
            if let due = data.dueDate(for: type) { changes.append(due) }
        }

        let horizon = now.addingTimeInterval(30 * 60)
        var entries = [TrackEntry(date: now, data: data)]
        for date in changes.filter({ $0 > now && $0 < horizon }).sorted() {
            entries.append(TrackEntry(date: date.addingTimeInterval(0.5), data: data))
        }
        completion(Timeline(entries: entries, policy: .after(horizon)))
    }
}

// MARK: - Vues

struct TrackWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrackEntry

    var body: some View {
        Group {
            if let pending = entry.data.pendingType(at: entry.date) {
                ConfirmView(type: pending)
            } else if let done = entry.data.justConfirmedType(at: entry.date) {
                DoneView(type: done, date: entry.data.lastConfirmedAt ?? entry.date)
            } else {
                grid
            }
        }
        // Toucher en dehors d'un bouton (ex. la case « Journal ») ouvre le journal dans l'app.
        .widgetURL(URL(string: "trackmythings://log"))
    }

    private var columns: Int {
        switch family {
        case .systemSmall: return 2
        case .systemLarge: return 3
        default: return 4
        }
    }

    private var rows: Int {
        switch family {
        case .systemLarge: return 4
        default: return 2
        }
    }

    private var grid: some View {
        let capacity = columns * rows - 1 // une case réservée au journal
        let types = Array(entry.data.types.prefix(capacity))
        let cells: [Cell] = types.map { .event($0) } + [.journal]
        let gridRows = stride(from: 0, to: cells.count, by: columns).map {
            Array(cells[$0..<min($0 + columns, cells.count)])
        }

        return VStack(spacing: 6) {
            ForEach(gridRows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(gridRows[r]) { cell in
                        cellView(cell)
                    }
                    if gridRows[r].count < columns {
                        ForEach(0..<(columns - gridRows[r].count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .event(let type):
            let overdue = entry.data.isOverdue(type, at: entry.date)
            Button(intent: SelectEventIntent(typeID: type.id)) {
                Tile(emoji: type.emoji,
                     title: type.name,
                     subtitle: family == .systemSmall ? nil : Format.ago(entry.data.lastDate(for: type.id), now: entry.date),
                     highlight: overdue ? .red : nil)
            }
            .buttonStyle(.plain)
        case .journal:
            Tile(emoji: "📒", title: "Journal", subtitle: nil, highlight: nil)
        }
    }

    enum Cell: Identifiable {
        case event(EventType)
        case journal

        var id: String {
            switch self {
            case .event(let t): return t.id.uuidString
            case .journal: return "journal"
            }
        }
    }
}

private struct Tile: View {
    let emoji: String
    let title: String
    let subtitle: String?
    let highlight: Color?

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji).font(.title2)
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(highlight ?? .secondary)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((highlight ?? Color.gray).opacity(highlight == nil ? 0.15 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(highlight ?? .clear, lineWidth: 1.5)
        )
    }
}

private struct ConfirmView: View {
    let type: EventType

    var body: some View {
        VStack(spacing: 8) {
            Text("\(type.emoji) \(type.name)")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("Enregistrer maintenant ?")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(intent: CancelSelectionIntent()) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)))
                }
                .buttonStyle(.plain)
                Button(intent: ConfirmEventIntent(typeID: type.id)) {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                }
                .buttonStyle(.plain)
            }
            .frame(maxHeight: 64)
        }
    }
}

private struct DoneView: View {
    let type: EventType
    let date: Date

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("\(type.emoji) \(type.name)")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("enregistré à \(date.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
