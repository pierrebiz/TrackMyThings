import Foundation

enum IntervalUnit: String, Codable, CaseIterable, Identifiable {
    case hours, days, weeks

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .hours: return 3600
        case .days: return 86_400
        case .weeks: return 7 * 86_400
        }
    }

    func label(_ value: Int) -> String {
        switch self {
        case .hours: return value > 1 ? "heures" : "heure"
        case .days: return value > 1 ? "jours" : "jour"
        case .weeks: return value > 1 ? "semaines" : "semaine"
        }
    }
}

/// Un type d'événement configurable (ex. « Statine », « Charge voiture »).
struct EventType: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    /// Envoyer une alerte si l'événement n'a pas été fait dans l'intervalle.
    var reminderEnabled: Bool = true
    var intervalValue: Int = 1
    var intervalUnit: IntervalUnit = .days

    var interval: TimeInterval { TimeInterval(max(intervalValue, 1)) * intervalUnit.seconds }

    var frequencyLabel: String {
        if intervalValue <= 1 { return "chaque \(intervalUnit.label(1))" }
        let article = intervalUnit == .days ? "tous les" : "toutes les"
        return "\(article) \(intervalValue) \(intervalUnit.label(intervalValue))"
    }

    init(id: UUID = UUID(), name: String, emoji: String, reminderEnabled: Bool = true,
         intervalValue: Int = 1, intervalUnit: IntervalUnit = .days) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.reminderEnabled = reminderEnabled
        self.intervalValue = intervalValue
        self.intervalUnit = intervalUnit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "?"
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "•"
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? true
        intervalValue = try c.decodeIfPresent(Int.self, forKey: .intervalValue) ?? 1
        intervalUnit = try c.decodeIfPresent(IntervalUnit.self, forKey: .intervalUnit) ?? .days
    }
}

/// Une occurrence enregistrée. Le nom et l'emoji sont copiés pour que le journal
/// reste lisible même si le type est renommé ou supprimé.
struct LogEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var typeID: UUID
    var typeName: String
    var emoji: String
    var date: Date
}

struct AppData: Codable {
    var types: [EventType]
    var entries: [LogEntry]

    // Réglages
    var askConfirmation: Bool = true
    var closeAppAfterLog: Bool = true

    static var initial: AppData {
        AppData(
            types: [
                EventType(name: "Statine", emoji: "💊", intervalValue: 1, intervalUnit: .days),
                EventType(name: "Charge voiture", emoji: "🔌", intervalValue: 3, intervalUnit: .days),
            ],
            entries: []
        )
    }

    init(types: [EventType], entries: [LogEntry]) {
        self.types = types
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        types = try c.decodeIfPresent([EventType].self, forKey: .types) ?? []
        entries = try c.decodeIfPresent([LogEntry].self, forKey: .entries) ?? []
        askConfirmation = try c.decodeIfPresent(Bool.self, forKey: .askConfirmation) ?? true
        closeAppAfterLog = try c.decodeIfPresent(Bool.self, forKey: .closeAppAfterLog) ?? true
    }

    func type(_ id: UUID?) -> EventType? {
        guard let id else { return nil }
        return types.first { $0.id == id }
    }

    func lastDate(for typeID: UUID) -> Date? {
        entries.lazy.filter { $0.typeID == typeID }.map(\.date).max()
    }

    func dueDate(for type: EventType) -> Date? {
        guard type.reminderEnabled, let last = lastDate(for: type.id) else { return nil }
        return last.addingTimeInterval(type.interval)
    }

    func isOverdue(_ type: EventType, at now: Date = Date()) -> Bool {
        guard let due = dueDate(for: type) else { return false }
        return due < now
    }
}

enum Format {
    /// Durée courte : « 12 min », « 5 h », « 3 j ».
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        if s < 3600 { return "\(Int(s / 60)) min" }
        if s < 48 * 3600 { return "\(Int(s / 3600)) h" }
        return "\(Int(s / 86_400)) j"
    }

    static func ago(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "jamais" }
        let s = now.timeIntervalSince(date)
        if s < 60 { return "à l'instant" }
        return "il y a \(duration(s))"
    }
}
