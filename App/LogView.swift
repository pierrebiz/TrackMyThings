import SwiftUI

/// Journal de tous les événements, tous types confondus (filtrable).
struct LogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: UUID?
    @State private var showingAdd = false

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
                    StatusRow(type: type, data: model.data)
                }
            }

            if filtered.isEmpty {
                Text("Aucune entrée pour l'instant.").foregroundStyle(.secondary)
            }

            ForEach(days, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())) {
                    ForEach(group.items) { entry in
                        HStack {
                            Text(entry.emoji)
                            Text(entry.typeName)
                            Spacer()
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
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
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddEntrySheet(initialType: filter ?? model.data.types.first?.id)
        }
    }
}

private struct StatusRow: View {
    let type: EventType
    let data: AppData

    var body: some View {
        let count30 = data.entries.filter {
            $0.typeID == type.id && $0.date > Date().addingTimeInterval(-30 * 86_400)
        }.count
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(type.emoji) \(type.name)").font(.headline)
                Spacer()
                if data.isOverdue(type) {
                    Text("EN RETARD").font(.caption.bold()).foregroundStyle(.red)
                }
            }
            Text("Dernière fois : \(Format.ago(data.lastDate(for: type.id))) · \(count30) fois sur 30 jours")
                .font(.caption)
                .foregroundStyle(.secondary)
            if type.reminderEnabled {
                Text("Alerte si pas fait \(type.frequencyLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Ajout manuel d'une entrée (oubli, date passée…).
private struct AddEntrySheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var typeID: UUID?
    @State private var date = Date()

    init(initialType: UUID?) {
        _typeID = State(initialValue: initialType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Événement", selection: $typeID) {
                    ForEach(model.data.types) { type in
                        Text("\(type.emoji) \(type.name)").tag(UUID?.some(type.id))
                    }
                }
                DatePicker("Date", selection: $date, in: ...Date())
            }
            .navigationTitle("Ajouter une entrée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        guard let typeID else { return }
                        Task {
                            await model.log(typeID: typeID, at: date)
                            dismiss()
                        }
                    }
                    .disabled(typeID == nil)
                }
            }
        }
    }
}
