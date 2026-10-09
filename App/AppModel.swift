import SwiftUI
import UserNotifications
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data: AppData = Store.load()
    @Published private(set) var notificationsAuthorized = true

    func reload() {
        data = Store.load()
    }

    func mutate(_ body: (inout AppData) -> Void) {
        data = Store.update(body)
        WidgetCenter.shared.reloadAllTimelines()
        rescheduleReminders()
    }

    func log(typeID: UUID, at date: Date = Date()) async {
        await Tracker.log(typeID: typeID, at: date)
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteEntries(_ ids: Set<UUID>) {
        mutate { $0.entries.removeAll { ids.contains($0.id) } }
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
