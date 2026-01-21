import UserNotifications

final class NotificationManager: ObservableObject {
    @Published var permissionGranted = false

    init() {
        checkPermission()
    }

    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        }
    }

    func sendNotification(blockedApp: String, restoredApp: String) {
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Blocked \(blockedApp)"
        content.body = "Restored focus to \(restoredApp)"
        content.sound = nil // Silent - just visual

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
