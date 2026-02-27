import SwiftUI

class NavigationState: ObservableObject {
    static let shared = NavigationState()
    @Published var pendingExecutionId: String?
}

@main
struct KlaudimeroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var navigationState = NavigationState.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                JobListView()
                    .tabItem {
                        Label("Jobs", systemImage: "clock.arrow.circlepath")
                    }
                HeartbeatView()
                    .tabItem {
                        Label("Heartbeat", systemImage: "heart.circle")
                    }
            }
            .environmentObject(APIClient.shared)
            .environmentObject(navigationState)
            .sheet(item: $navigationState.pendingExecutionId) { executionId in
                NavigationStack {
                    ExecutionLoadingView(executionId: executionId)
                        .environmentObject(APIClient.shared)
                }
            }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.requestPermission()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.registerToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let executionId = userInfo["execution_id"] as? String {
            DispatchQueue.main.async {
                NavigationState.shared.pendingExecutionId = executionId
            }
        }
        completionHandler()
    }
}
