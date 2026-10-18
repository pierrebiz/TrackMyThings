import SwiftUI

/// Journal de tous les événements, tous types confondus (filtrable).
struct LogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: UUID?
    @State private var showingAdd = false
    @State private var editing: LogEntry?

    private var filtered: [LogEntry] {
        model.data.entries
            .filter { filter == nil || $0.typeID == filter }
            .sorted { $0.date > $1.date }
    }

    private var days: [(day: Date, items: [LogEntry])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            Section {
                Picker("Afficher", selection: $filter) {
                    Text("Tous les événements").tag(UUID?.none)
                    ForEach(model.data.types) { type in
                        Text("\(type.emoji) \(type.name)").tag(UUID?.some(type.id))
                    }
                }
                ForEach(model.data.types.filter { filter == nil || $0.id == filter }) { type in
                    StatusRow(type: type, data: model.data, now: model.now)
                }
            }

            if filtered.isEmpty {
                Text("Aucune entrée pour l'instant.").foregroundStyle(.secondary)
            }

            ForEach(days, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())) {
                    ForEach(group.items) { entry in
                        // Toucher une entrée pour changer son heure, sa date ou son type.
                        Button { editing = entry } label: {
                            HStack {
                                Text(entry.emoji)
                                Text(entry.typeName)
                                Spacer()
                                Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        model.deleteEntries(Set(offsets.map { group.items[$0].id }))
                    }
                }
            }
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: model.csvFile()) { Image(systemName: "square.and.arrow.up") }
                Button { showingAdd = true } label: { Label("Entrée manuelle", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            EntrySheet(initialType: filter ?? model.data.types.first?.id)
        }
        .sheet(item: $editing) { entry in
            EntrySheet(entry: entry)
        }
    }
}

private struct StatusRow: View {
    let type: EventType
    let data: AppData
    let now: Date

    var body: some View {
        let count30 = data.entries.filter {
            $0.typeID == type.id && $0.date > now.addingTimeInterval(-30 * 86_400)
        }.count
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(type.emoji) \(type.name)").font(.headline)
                Spacer()
                if data.isOverdue(type, at: now) {
                    Text("EN RETARD").font(.caption.bold()).foregroundStyle(.red)
                }
            }
            Text("Dernière fois : \(Format.ago(data.lastDate(for: type.id), now: now)) · \(count30) fois sur 30 jours")
                .font(.caption)
                .foregroundStyle(.secondary)
            if type.autoLog {
                Text("Automatique \(type.frequencyLabel)" + (type.nextOccurrence(after: now).map { " · prochain : \(Format.when($0))" } ?? ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if type.reminderEnabled {
                Text("Alerte si pas fait \(type.frequencyLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
