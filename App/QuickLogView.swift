import SwiftUI

/// Écran d'accueil de l'app : un bouton par type d'événement.
struct QuickLogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected: EventType?
    @State private var justLogged: EventType?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.data.types) { type in
                    Button {
                        if model.data.askConfirmation {
                            selected = type
                        } else {
                            record(type)
                        }
                    } label: {
                        EventButtonLabel(type: type, data: model.data)
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink(value: Route.log) {
                    VStack(spacing: 6) {
                        Text("📒").font(.system(size: 40))
                        Text("Journal").font(.headline)
                        Text("\(model.data.entries.count) entrées").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding()

            if model.data.types.isEmpty {
                ContentUnavailableView("Aucun type d'événement",
                                       systemImage: "list.bullet",
                                       description: Text("Ajoutez-en dans les réglages."))
            }
            if !model.notificationsAuthorized {
                Label("Notifications désactivées : les alertes de retard ne s'afficheront pas.",
                      systemImage: "bell.slash")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }
        }
        .navigationTitle("TrackMyThings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) { Image(systemName: "gearshape") }
            }
        }
        .confirmationDialog(
            selected.map { "Enregistrer « \($0.name) » maintenant ?" } ?? "",
            isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
            titleVisibility: .visible,
            presenting: selected
        ) { type in
            Button("✓ \(type.emoji) \(type.name)") { record(type) }
            Button("Annuler", role: .cancel) {}
        }
        .overlay {
            if let type = justLogged {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("\(type.emoji) \(type.name) enregistré").font(.headline)
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func record(_ type: EventType) {
        Task {
            await model.log(typeID: type.id)
            withAnimation { justLogged = type }
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation { justLogged = nil }
            if model.data.closeAppAfterLog {
                // Renvoie à l'écran d'accueil (équivalent d'un appui sur le bouton Home).
                UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            }
        }
    }
}

private struct EventButtonLabel: View {
    let type: EventType
    let data: AppData

    var body: some View {
        let overdue = data.isOverdue(type)
        VStack(spacing: 6) {
            Text(type.emoji).font(.system(size: 40))
            Text(type.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Text(Format.ago(data.lastDate(for: type.id)))
                .font(.caption)
                .foregroundStyle(overdue ? .red : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(overdue ? Color.red.opacity(0.12) : Color.gray.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(overdue ? Color.red : .clear, lineWidth: 2)
        )
    }
}
