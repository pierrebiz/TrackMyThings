import Foundation

/// Persistance JSON partagée entre l'app et le widget via un App Group.
enum Store {
    /// Lu depuis l'Info.plist (clé `AppGroupID`, alimentée par le réglage de build `APP_GROUP_ID`).
    static let appGroupID: String =
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? "group.biz.besnard.trackmythings"

    /// `true` si le conteneur partagé est accessible (sinon le widget ne voit pas les données de l'app).
    static var isSharedContainerAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static var fileURL: URL {
        let fm = FileManager.default
        let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("trackmythings.json")
    }

    static func load() -> AppData {
        guard let raw = try? Data(contentsOf: fileURL) else {
            let initial = AppData.initial
            save(initial)
            return initial
        }
        return (try? decoder.decode(AppData.self, from: raw)) ?? AppData.initial
    }

    static func save(_ data: AppData) {
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }

    /// Lit, modifie et réécrit les données. Retourne la version sauvegardée.
    @discardableResult
    static func update(_ body: (inout AppData) -> Void) -> AppData {
        var data = load()
        body(&data)
        save(data)
        return data
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// Actions métier partagées par l'app, le widget et les notifications.
enum Tracker {
    @discardableResult
    static func log(typeID: UUID, at date: Date = Date()) async -> LogEntry? {
        var entry: LogEntry?
        let data = Store.update { d in
            d.pendingTypeID = nil
            d.pendingSince = nil
            guard let t = d.type(typeID) else { return }
            let e = LogEntry(typeID: t.id, typeName: t.name, emoji: t.emoji, date: date)
            d.entries.append(e)
            d.lastConfirmedTypeID = t.id
            d.lastConfirmedAt = Date()
            entry = e
        }
        await ReminderScheduler.rescheduleAll(data: data)
        return entry
    }
}
