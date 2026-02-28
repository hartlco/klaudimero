import SwiftUI
import UserNotifications

enum MenuAction: Equatable {
    case newChat
    case newJob
    case openSettings
    case refresh
}

class NavigationState: ObservableObject {
    static let shared = NavigationState()
    @Published var pendingExecutionId: String?
    @Published var pendingSessionId: String?
    @Published var selectedTab: Int = 0
    @Published var pendingMenuAction: MenuAction?
}

@main
struct KlaudimeroApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var chatStore = ChatStore.shared

    var body: some Scene {
        WindowGroup {
            TabView(selection: $navigationState.selectedTab) {
                ChatListView()
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(0)
                JobListView()
                    .tabItem {
                        Label("Jobs", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)
                HeartbeatView()
                    .tabItem {
                        Label("Heartbeat", systemImage: "heart.circle")
                    }
                    .tag(2)
            }
            .environmentObject(APIClient.shared)
            .environmentObject(navigationState)
            .environmentObject(chatStore)
            .sheet(item: $navigationState.pendingExecutionId) { executionId in
                NavigationStack {
                    ExecutionLoadingView(executionId: executionId)
                        .environmentObject(APIClient.shared)
                }
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    navigationState.selectedTab = 0
                    navigationState.pendingMenuAction = .newChat
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Job") {
                    navigationState.selectedTab = 1
                    navigationState.pendingMenuAction = .newJob
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Settings...") {
                    navigationState.selectedTab = 1
                    navigationState.pendingMenuAction = .openSettings
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Navigation") {
                Button("Chat") { navigationState.selectedTab = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Jobs") { navigationState.selectedTab = 1 }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Heartbeat") { navigationState.selectedTab = 2 }
                    .keyboardShortcut("3", modifiers: .command)
            }

            CommandGroup(replacing: .toolbar) {
                Button("Refresh") {
                    navigationState.pendingMenuAction = .refresh
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

#if os(iOS)
import UIKit

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
        if let sessionId = userInfo["session_id"] as? String, !sessionId.isEmpty {
            DispatchQueue.main.async {
                NavigationState.shared.selectedTab = 0
                NavigationState.shared.pendingSessionId = sessionId
            }
        } else if let executionId = userInfo["execution_id"] as? String {
            DispatchQueue.main.async {
                NavigationState.shared.pendingExecutionId = executionId
            }
        }
        completionHandler()
    }
}

#elseif os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.requestPermission()
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.registerToken(deviceToken)
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let sessionId = userInfo["session_id"] as? String, !sessionId.isEmpty {
            DispatchQueue.main.async {
                NavigationState.shared.selectedTab = 0
                NavigationState.shared.pendingSessionId = sessionId
            }
        } else if let executionId = userInfo["execution_id"] as? String {
            DispatchQueue.main.async {
                NavigationState.shared.pendingExecutionId = executionId
            }
        }
        completionHandler()
    }
}
#endif
