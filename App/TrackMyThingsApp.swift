import SwiftUI
import UserNotifications

@main
struct TrackMyThingsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task {
                    _ = await ReminderScheduler.requestAuthorization()
                    await model.refreshNotificationStatus()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reload()
                model.rescheduleReminders()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
        return true
    }

    // Afficher les alertes même quand l'app est ouverte.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Bouton « ✓ Fait maintenant » sur la notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == ReminderScheduler.doneActionID,
              let raw = response.notification.request.content.userInfo["typeID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await Tracker.log(typeID: id)
    }
}

enum Route: Hashable {
    case log
    case settings
    case editType(UUID)
    case newType
}

struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            QuickLogView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .log: LogView()
                    case .settings: SettingsView()
                    case .editType(let id): EventTypeEditor(typeID: id)
                    case .newType: EventTypeEditor(typeID: nil)
                    }
                }
        }
    }
}
