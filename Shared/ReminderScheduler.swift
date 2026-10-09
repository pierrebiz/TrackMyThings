import Foundation
import UserNotifications

/// Programme des notifications locales quand un événement n'a pas été fait à temps.
/// Tout est recalculé à chaque enregistrement : pas de serveur nécessaire.
enum ReminderScheduler {
    static let categoryID = "OVERDUE"
    static let doneActionID = "DONE_NOW"

    /// Relances après l'échéance : à l'échéance, +2 h, +6 h, +1 j, +2 j, +3 j.
    static let followUps: [TimeInterval] = [0, 2, 6, 24, 48, 72].map { $0 * 3600 }

    /// iOS limite à 64 notifications en attente par app.
    private static let maxPending = 60

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func registerCategories() {
        let done = UNNotificationAction(identifier: doneActionID, title: "✓ Fait maintenant", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [done], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func rescheduleAll(data: AppData) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        var requests: [(fire: Date, request: UNNotificationRequest)] = []

        for type in data.types where type.reminderEnabled {
            guard let last = data.lastDate(for: type.id) else { continue }
            let due = last.addingTimeInterval(type.interval)
            for (index, offset) in followUps.enumerated() {
                let fire = due.addingTimeInterval(offset)
                let delay = fire.timeIntervalSince(now)
                guard delay > 5 else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(type.emoji) \(type.name) : à faire"
                content.body = "Dernière fois il y a \(Format.duration(fire.timeIntervalSince(last))) — fréquence prévue : \(type.frequencyLabel)."
                content.sound = .default
                content.categoryIdentifier = categoryID
                content.threadIdentifier = type.id.uuidString
                content.userInfo = ["typeID": type.id.uuidString]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(identifier: "\(type.id.uuidString)-\(index)", content: content, trigger: trigger)
                requests.append((fire, request))
            }
        }

        for item in requests.sorted(by: { $0.fire < $1.fire }).prefix(maxPending) {
            try? await center.add(item.request)
        }
    }
}
