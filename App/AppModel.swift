import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data: AppData = Store.load()
    @Published private(set) var notificationsAuthorized = true
    /// Heure de référence pour les « il y a … » et les retards, rafraîchie régulièrement :
    /// sans elle, SwiftUI garde l'affichage calculé lors du dernier enregistrement.
    @Published private(set) var now = Date()

    func reload() {
        data = Store.load()
        now = Date()
    }

    func tick() {
        now = Date()
    }

    // État de la sauvegarde GitHub, pour l'écran Réglages.
    @Published private(set) var backupConfigured = GitHubBackup.isConfigured
    @Published private(set) var backupLastSuccess = GitHubBackup.lastSuccess
    @Published private(set) var backupLastError = GitHubBackup.lastError
    @Published private(set) var isSyncing = false

    func mutate(_ body: (inout AppData) -> Void) {
        data = Store.update(body)
        rescheduleReminders()
        Task { await backup() }
    }

    /// Enregistre l'événement puis attend la sauvegarde, pour qu'elle soit finie
    /// avant la fermeture automatique de l'app.
    func log(typeID: UUID, at date: Date = Date()) async {
        await Tracker.log(typeID: typeID, at: date)
        reload()
        await backup()
    }

    func deleteEntries(_ ids: Set<UUID>) {
        mutate { d in
            d.entries.removeAll { ids.contains($0.id) }
            d.deletedEntryIDs.append(contentsOf: ids)
        }
    }

    func deleteTypes(_ ids: Set<UUID>) {
        mutate { d in
            d.types.removeAll { ids.contains($0.id) }
            d.deletedTypeIDs.append(contentsOf: ids)
        }
    }

    /// Synchronise avec GitHub (si un jeton est configuré) et recharge les données fusionnées.
    func backup() async {
        guard GitHubBackup.isConfigured else { return }
        isSyncing = true
        await GitHubBackup.shared.sync()
        isSyncing = false
        reload()
        rescheduleReminders()
        refreshBackupState()
    }

    func configureBackup(repo: String, token: String?) async {
        GitHubBackup.repo = repo
        if let token, !token.isEmpty { Keychain.token = token }
        refreshBackupState()
        await backup()
    }

    func removeBackupToken() {
        Keychain.token = nil
        refreshBackupState()
    }

    private func refreshBackupState() {
        backupConfigured = GitHubBackup.isConfigured
        backupLastSuccess = GitHubBackup.lastSuccess
        backupLastError = GitHubBackup.lastError
    }

    func rescheduleReminders() {
        let snapshot = data
        Task { await ReminderScheduler.rescheduleAll(data: snapshot) }
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Export CSV de tout le journal, écrit dans un fichier temporaire pour le partage.
    func csvFile() -> URL {
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        var lines = ["date;type;emoji"]
        for e in data.entries.sorted(by: { $0.date < $1.date }) {
            let name = e.typeName.replacingOccurrences(of: ";", with: ",")
            lines.append("\(iso.string(from: e.date));\(name);\(e.emoji)")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TrackMyThings-journal.csv")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
