import Foundation

/// Persistance JSON partagée entre l'app et le widget via un App Group.
enum Store {
    /// Groupe configuré au build (clé `AppGroupID` de l'Info.plist, réglage `APP_GROUP_ID`).
    static let configuredAppGroupID: String =
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? "group.biz.besnard.trackmythings"

    /// Groupe réellement utilisable. Les outils de sideload avec un Apple ID gratuit
    /// (AltStore, SideStore, Sideloadly…) renomment le groupe, typiquement
    /// `group.xxx` → `group.xxx.<TEAMID>` : on le retrouve dans l'Info.plist (`ALTAppGroups`)
    /// ou dans le profil de provisioning embarqué.
    static let appGroupID: String = resolveAppGroupID()

    /// `true` si le conteneur partagé est accessible (sinon le widget ne voit pas les données de l'app).
    static var isSharedContainerAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    private static func resolveAppGroupID() -> String {
        let configured = configuredAppGroupID
        let fm = FileManager.default
        func usable(_ id: String) -> Bool {
            fm.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
        }
        if usable(configured) { return configured }

        // Le groupe renommé commence par le groupe configuré : on le préfère, puis n'importe quel groupe utilisable.
        let candidates = groupsFromInfoPlist() + groupsFromProvisioningProfile()
        let ranked = candidates.filter { $0.hasPrefix(configured) } + candidates.filter { !$0.hasPrefix(configured) }
        return ranked.first(where: usable) ?? configured
    }

    /// Clé ajoutée par AltStore / SideStore dans l'app et dans chaque extension.
    private static func groupsFromInfoPlist() -> [String] {
        switch Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") {
        case let groups as [String]: return groups
        case let group as String: return [group]
        default: return []
        }
    }

    /// Entitlements du profil `embedded.mobileprovision` (présent quel que soit l'outil de signature).
    private static func groupsFromProvisioningProfile() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let start = raw.range(of: Data("<?xml".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), in: start.lowerBound..<raw.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: raw.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
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
