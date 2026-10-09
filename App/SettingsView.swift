import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(model.data.types) { type in
                    NavigationLink(value: Route.editType(type.id)) {
                        VStack(alignment: .leading) {
                            Text("\(type.emoji) \(type.name)")
                            Text(type.reminderEnabled ? "Alerte si pas fait \(type.frequencyLabel)" : "Pas d'alerte")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { from, to in
                    model.mutate { $0.types.move(fromOffsets: from, toOffset: to) }
                }
                .onDelete { offsets in
                    let ids = Set(offsets.map { model.data.types[$0].id })
                    model.mutate { $0.types.removeAll { ids.contains($0.id) } }
                }
                NavigationLink(value: Route.newType) {
                    Label("Ajouter un type d'événement", systemImage: "plus")
                }
            } header: {
                Text("Types d'événements")
            } footer: {
                Text("L'ordre ici est l'ordre du widget. Les entrées du journal sont conservées si vous supprimez un type.")
            }

            Section("Comportement") {
                Toggle("Demander confirmation", isOn: Binding(
                    get: { model.data.askConfirmation },
                    set: { value in model.mutate { $0.askConfirmation = value } }))
                Toggle("Fermer l'app après enregistrement", isOn: Binding(
                    get: { model.data.closeAppAfterLog },
                    set: { value in model.mutate { $0.closeAppAfterLog = value } }))
            }

            Section("Notifications") {
                if model.notificationsAuthorized {
                    Label("Alertes activées", systemImage: "bell.badge")
                } else {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Activer les notifications dans Réglages", systemImage: "bell.slash")
                    }
                }
            }

            if !Store.isSharedContainerAvailable {
                Section("Widget") {
                    Label("App Group « \(Store.appGroupID) » indisponible : le widget ne verra pas les données de l'app. Vérifiez la signature (voir README).",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Réglages")
        .toolbar { EditButton() }
        .task { await model.refreshNotificationStatus() }
    }
}

struct EventTypeEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let typeID: UUID?

    @State private var draft = EventType(name: "", emoji: "✅")
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Événement") {
                TextField("Nom (ex. Statine)", text: $draft.name)
                TextField("Emoji", text: $draft.emoji)
                    .onChange(of: draft.emoji) { _, value in
                        if value.count > 1 { draft.emoji = String(value.suffix(1)) }
                    }
            }
            Section {
                Toggle("Alerte si pas fait à temps", isOn: $draft.reminderEnabled)
                if draft.reminderEnabled {
                    Stepper(value: $draft.intervalValue, in: 1...365) {
                        Text(draft.frequencyLabel.prefix(1).uppercased() + draft.frequencyLabel.dropFirst())
                    }
                    Picker("Unité", selection: $draft.intervalUnit) {
                        ForEach(IntervalUnit.allCases) { unit in
                            Text(unit.label(2).capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Fréquence")
            } footer: {
                Text("Une notification est envoyée à l'échéance (dernière fois + intervalle), puis relancée après 2 h, 6 h, 1, 2 et 3 jours. Astuce : pour une prise quotidienne à heure variable, choisissez par ex. 26 heures.")
            }
        }
        .navigationTitle(typeID == nil ? "Nouveau type" : "Modifier")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { save() }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let typeID, let existing = model.data.type(typeID) {
                draft = existing
            }
        }
    }

    private func save() {
        var type = draft
        type.name = type.name.trimmingCharacters(in: .whitespaces)
        if type.emoji.isEmpty { type.emoji = "✅" }
        model.mutate { d in
            if let index = d.types.firstIndex(where: { $0.id == type.id }) {
                d.types[index] = type
            } else {
                d.types.append(type)
            }
        }
        dismiss()
    }
}
