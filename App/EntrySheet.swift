import SwiftUI

/// Entrée manuelle (type + date et heure au choix) ou modification d'une entrée du journal.
struct EntrySheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Entrée modifiée, ou `nil` pour une nouvelle entrée manuelle.
    let entry: LogEntry?
    @State private var typeID: UUID?
    @State private var date: Date
    @State private var confirmingDelete = false

    init(entry: LogEntry? = nil, initialType: UUID? = nil) {
        self.entry = entry
        _typeID = State(initialValue: entry?.typeID ?? initialType)
        _date = State(initialValue: entry?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Événement", selection: $typeID) {
                    ForEach(model.data.types) { type in
                        Text("\(type.emoji) \(type.name)").tag(UUID?.some(type.id))
                    }
                    // Type supprimé depuis : on garde l'entrée sélectionnable telle quelle.
                    if let entry, model.data.type(entry.typeID) == nil {
                        Text("\(entry.emoji) \(entry.typeName)").tag(UUID?.some(entry.typeID))
                    }
                }
                DatePicker("Date et heure", selection: $date, in: ...Date())

                if entry != nil {
                    Section {
                        Button("Supprimer l'entrée", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Entrée manuelle" : "Modifier l'entrée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(entry == nil ? "Ajouter" : "Enregistrer") { save() }
                        .disabled(typeID == nil)
                }
            }
            .confirmationDialog("Supprimer cette entrée ?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let entry { model.deleteEntries([entry.id]) }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let typeID else { return }
        if let entry {
            model.updateEntry(id: entry.id, typeID: typeID, date: date)
            dismiss()
        } else {
            Task {
                await model.log(typeID: typeID, at: date)
                dismiss()
            }
        }
    }
}
