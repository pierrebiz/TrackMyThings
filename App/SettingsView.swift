import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            // Section réservée aux types : le glisser-déposer ne fonctionne bien
            // que si la section ne contient que les lignes déplaçables.
            Section {
                ForEach(model.data.types) { type in
                    if editMode.isEditing {
                        typeRow(type)
                    } else {
                        NavigationLink(value: Route.editType(type.id)) { typeRow(type) }
                    }
                }
                .onMove { from, to in
                    model.mutate { $0.types.move(fromOffsets: from, toOffset: to) }
                }
                .onDelete { offsets in
                    model.deleteTypes(Set(offsets.map { model.data.types[$0].id }))
                }
                .moveDisabled(!editMode.isEditing)
            } header: {
                Text("Types d'événements")
            } footer: {
                Text("Pour changer l'ordre, touchez « Réordonner » puis faites glisser les poignées ≡. Les entrées du journal sont conservées si vous supprimez un type.")
            }

            Section {
                NavigationLink(value: Route.newType) {
                    Label("Ajouter un type d'événement", systemImage: "plus")
                }
            }

            Section("Comportement") {
                Toggle("Demander confirmation", isOn: Binding(
                    get: { model.data.askConfirmation },
                    set: { value in model.mutate { $0.askConfirmation = value } }))
                Toggle("Fermer l'app après enregistrement", isOn: Binding(
                    get: { model.data.closeAppAfterLog },
                    set: { value in model.mutate { $0.closeAppAfterLog = value } }))
            }

            BackupSection()

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
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .navigationTitle("Réglages")
        .toolbar {
            Button(editMode.isEditing ? "OK" : "Réordonner") {
                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
            }
        }
        .task { await model.refreshNotificationStatus() }
    }

    private func typeRow(_ type: EventType) -> some View {
        VStack(alignment: .leading) {
            Text("\(type.emoji) \(type.name)")
            Text(type.autoLog ? "Automatique \(type.frequencyLabel)"
                 : type.reminderEnabled ? "Alerte si pas fait \(type.frequencyLabel)" : "Pas d'alerte")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Réglage de la sauvegarde GitHub (voir README pour créer le jeton).
private struct BackupSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var repo = GitHubBackup.repo
    @State private var token = ""

    var body: some View {
        Section {
            TextField("propriétaire/dépôt", text: $repo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField(model.backupConfigured ? "Jeton enregistré (coller pour remplacer)" : "Jeton d'accès GitHub",
                        text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                let newToken = token
                token = ""
                Task { await model.configureBackup(repo: repo, token: newToken) }
            } label: {
                HStack {
                    Label(model.backupConfigured ? "Synchroniser maintenant" : "Enregistrer et synchroniser",
                          systemImage: "arrow.triangle.2.circlepath")
                    if model.isSyncing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(model.isSyncing || (!model.backupConfigured && token.isEmpty))

            if let error = model.backupLastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if let date = model.backupLastSuccess {
                Label("Dernière sauvegarde : \(Format.ago(date, now: model.now))", systemImage: "checkmark.icloud")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            if model.backupConfigured {
                Button("Supprimer le jeton", role: .destructive) { model.removeBackupToken() }
            }
        } header: {
            Text("Sauvegarde GitHub")
        } footer: {
            Text("Après chaque modification, le journal est envoyé dans \(GitHubBackup.filePath) du dépôt. Les entrées de la sauvegarde absentes du téléphone (par exemple après une réinstallation) sont récupérées automatiquement.")
        }
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
                Picker("Validation", selection: $draft.autoLog) {
                    Text("Je confirme").tag(false)
                    Text("Automatique").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Validation")
            } footer: {
                Text(draft.autoLog
                     ? "L'événement est ajouté au journal tout seul à chaque échéance, sans rien toucher (ex. sortir les poubelles). Si ça n'a pas été fait, supprimez l'entrée dans le journal."
                     : "Vous enregistrez l'événement vous-même, avec confirmation.")
            }

            if draft.autoLog {
                Section {
                    DatePicker("Première échéance", selection: Binding(
                        get: { draft.autoStart ?? Self.defaultAutoStart },
                        set: { draft.autoStart = $0 }))
                    frequencyControls
                    Toggle("Notification à chaque échéance", isOn: $draft.reminderEnabled)
                } header: {
                    Text("Planning")
                } footer: {
                    Text("Échéances : la première, puis \(draft.frequencyLabel), à la même heure. Si la première est dans le passé, les échéances passées sont ajoutées au journal.")
                }
            } else {
                Section {
                    Toggle("Alerte si pas fait à temps", isOn: $draft.reminderEnabled)
                    if draft.reminderEnabled {
                        frequencyControls
                    }
                } header: {
                    Text("Fréquence")
                } footer: {
                    Text("Une notification est envoyée à l'échéance (dernière fois + intervalle), puis relancée après 2 h, 6 h, 1, 2 et 3 jours. Astuce : pour une prise quotidienne à heure variable, choisissez par ex. 26 heures.")
                }
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

    @ViewBuilder
    private var frequencyControls: some View {
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

    /// Par défaut : la prochaine heure pleine.
    private static var defaultAutoStart: Date {
        let calendar = Calendar.current
        let hour = calendar.dateInterval(of: .hour, for: Date())?.start ?? Date()
        return calendar.date(byAdding: .hour, value: 1, to: hour) ?? Date()
    }

    private func save() {
        var type = draft
        type.name = type.name.trimmingCharacters(in: .whitespaces)
        if type.emoji.isEmpty { type.emoji = "✅" }
        if type.autoLog && type.autoStart == nil { type.autoStart = Self.defaultAutoStart }
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
