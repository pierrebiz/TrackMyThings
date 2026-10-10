import Foundation
import Security

/// Sauvegarde du journal dans un dépôt GitHub privé (fichier `trackmythings.json`).
/// Chaque synchronisation fusionne d'abord la sauvegarde distante dans les données locales,
/// puis envoie le résultat : une réinstallation récupère donc l'historique au lieu de l'écraser.
actor GitHubBackup {
    static let shared = GitHubBackup()

    static let defaultRepo = "pierrebiz/trackmythings-data"
    static let filePath = "trackmythings.json"

    private static let repoKey = "backupRepo"
    private static let lastSuccessKey = "backupLastSuccess"
    private static let lastErrorKey = "backupLastError"

    static var repo: String {
        get { UserDefaults.standard.string(forKey: repoKey) ?? defaultRepo }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: repoKey) }
    }

    static var isConfigured: Bool { Keychain.token != nil }
    static var lastSuccess: Date? { UserDefaults.standard.object(forKey: lastSuccessKey) as? Date }
    static var lastError: String? { UserDefaults.standard.string(forKey: lastErrorKey) }

    private var running: Task<Void, Never>?

    /// Synchronise (fusion + envoi). Les appels simultanés s'enchaînent.
    func sync() async {
        if let running { await running.value }
        let task = Task { await Self.perform() }
        running = task
        await task.value
        running = nil
    }

    private static func perform() async {
        guard let token = Keychain.token else { return }
        do {
            // Une seconde tentative si le fichier a changé entre la lecture et l'écriture.
            for attempt in 0..<2 {
                let remote = try await fetch(token: token)
                let merged = Store.update { local in
                    local = AppData.merge(local, with: remote?.data)
                }
                guard let raw = Store.encode(merged) else { return }
                if raw == remote?.raw {
                    succeed()
                    return
                }
                do {
                    try await upload(raw, sha: remote?.sha, token: token)
                    succeed()
                    return
                } catch BackupError.http(let code, _) where (code == 409 || code == 422) && attempt == 0 {
                    continue
                }
            }
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: lastErrorKey)
        }
    }

    private static func succeed() {
        UserDefaults.standard.set(Date(), forKey: lastSuccessKey)
        UserDefaults.standard.removeObject(forKey: lastErrorKey)
    }

    // MARK: - API GitHub (contents)

    private struct Remote {
        let sha: String
        let raw: Data
        let data: AppData?
    }

    private static func fetch(token: String) async throws -> Remote? {
        let request = try makeRequest("GET", token: token)
        let (body, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return nil } // pas encore de sauvegarde (ou dépôt inaccessible : l'envoi le dira)
        guard code == 200 else { throw BackupError.http(code, message(body)) }
        guard let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let sha = json["sha"] as? String,
              let content = json["content"] as? String,
              let raw = Data(base64Encoded: content, options: .ignoreUnknownCharacters)
        else { throw BackupError.badResponse }
        return Remote(sha: sha, raw: raw, data: Store.decode(raw))
    }

    private static func upload(_ raw: Data, sha: String?, token: String) async throws {
        var payload: [String: Any] = [
            "message": "Sauvegarde du \(Date().formatted(date: .numeric, time: .shortened))",
            "content": raw.base64EncodedString(),
        ]
        if let sha { payload["sha"] = sha }
        let request = try makeRequest("PUT", token: token, body: JSONSerialization.data(withJSONObject: payload))
        let (body, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else { throw BackupError.http(code, message(body)) }
    }

    private static func makeRequest(_ method: String, token: String, body: Data? = nil) throws -> URLRequest {
        let parts = repo.split(separator: "/").map(String.init)
        guard parts.count == 2,
              let url = URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])/contents/\(filePath)")
        else { throw BackupError.badRepo }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private static func message(_ body: Data) -> String {
        ((try? JSONSerialization.jsonObject(with: body)) as? [String: Any])?["message"] as? String ?? "erreur inconnue"
    }
}

enum BackupError: LocalizedError {
    case http(Int, String)
    case badResponse
    case badRepo

    var errorDescription: String? {
        switch self {
        case .http(401, _): return "Jeton refusé par GitHub (invalide ou expiré)."
        case .http(403, _), .http(404, _): return "Accès refusé : vérifiez le nom du dépôt et les droits du jeton (Contents : lecture et écriture)."
        case .http(let code, let message): return "Erreur GitHub \(code) : \(message)"
        case .badResponse: return "Réponse inattendue de GitHub."
        case .badRepo: return "Nom de dépôt invalide (format attendu : propriétaire/dépôt)."
        }
    }
}

/// Jeton GitHub rangé dans le trousseau de l'iPhone.
enum Keychain {
    private static let service = "TrackMyThings.github"

    static var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
            ]
            SecItemDelete(base as CFDictionary)
            guard let value = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            var item = base
            item[kSecValueData as String] = Data(value.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
