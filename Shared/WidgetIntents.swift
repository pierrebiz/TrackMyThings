import AppIntents
import Foundation

// Intents déclenchés par les boutons du widget interactif (iOS 17+).
// Ils s'exécutent en arrière-plan, sans ouvrir l'app.

/// 1er tap : choisit un événement. Le widget affiche alors « Confirmer ? »
/// (ou enregistre directement si la confirmation est désactivée).
struct SelectEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Choisir un événement"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Type")
    var typeID: String

    init() {}

    init(typeID: UUID) {
        self.typeID = typeID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: typeID) else { return .result() }
        if Store.load().askConfirmation {
            Store.update { d in
                d.pendingTypeID = id
                d.pendingSince = Date()
            }
        } else {
            await Tracker.log(typeID: id)
        }
        return .result()
    }
}

/// 2e tap : confirme et enregistre l'événement à l'heure actuelle.
struct ConfirmEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Confirmer l'événement"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Type")
    var typeID: String

    init() {}

    init(typeID: UUID) {
        self.typeID = typeID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: typeID) {
            await Tracker.log(typeID: id)
        }
        return .result()
    }
}

/// Annule la sélection en cours dans le widget.
struct CancelSelectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Annuler"
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        Store.update { d in
            d.pendingTypeID = nil
            d.pendingSince = nil
        }
        return .result()
    }
}
