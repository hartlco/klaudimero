import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func registerToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs token: \(token)")

        Task {
            do {
                try await APIClient.shared.registerDevice(token: token, name: UIDevice.current.name)
            } catch {
                print("Failed to register device: \(error)")
            }
        }
    }
}
