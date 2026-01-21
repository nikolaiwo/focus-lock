import SwiftUI
import ServiceManagement

@main
struct FocusLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("FocusLock", image: "MenuBarIcon") {
            MenuContent(
                settings: appDelegate.settings,
                notificationManager: appDelegate.notificationManager,
                openWindow: openWindow
            )
        }
        .menuBarExtraStyle(.menu)

        Window("Focus Log", id: "log") {
            LogWindowView(monitor: appDelegate.focusMonitor, settings: appDelegate.settings)
        }
        .defaultSize(width: 500, height: 400)

        Window("Blocked Apps", id: "blocked-apps") {
            BlockedAppsView(settings: appDelegate.settings)
        }
        .defaultSize(width: 400, height: 300)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings = SettingsStore()
    lazy var focusMonitor = FocusMonitor(settings: settings)
    let notificationManager = NotificationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        focusMonitor.startMonitoring()

        // Request notification permission if enabled
        if settings.notificationsEnabled {
            notificationManager.requestPermission()
        }

        focusMonitor.onFocusRestored = { [weak self] blockedApp, restoredApp in
            guard let self else { return }
            print("Focus restored: blocked=\(blockedApp), restored=\(restoredApp), notificationsEnabled=\(self.settings.notificationsEnabled)")
            if self.settings.notificationsEnabled {
                self.notificationManager.sendNotification(blockedApp: blockedApp, restoredApp: restoredApp)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor.stopMonitoring()
    }
}

struct MenuContent: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var notificationManager: NotificationManager
    let openWindow: OpenWindowAction

    @State private var launchAtLogin = false
    @State private var isUpdatingLaunchAtLogin = false

    var body: some View {
        Toggle("Protection Enabled", isOn: $settings.protectionEnabled)

        Toggle("Notifications", isOn: $settings.notificationsEnabled)
            .onChange(of: settings.notificationsEnabled) { newValue in
                if newValue && !notificationManager.permissionGranted {
                    notificationManager.requestPermission()
                }
            }

        Divider()

        Button("View Focus Log...") {
            openWindow(id: "log")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Blocked Apps...") {
            openWindow(id: "blocked-apps")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            .onChange(of: launchAtLogin) { newValue in
                guard !isUpdatingLaunchAtLogin else { return }
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to update launch at login: \(error)")
                    // Revert the toggle on failure
                    isUpdatingLaunchAtLogin = true
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                    isUpdatingLaunchAtLogin = false
                }
            }

        Divider()

        Button("Quit FocusLock") {
            NSApplication.shared.terminate(nil)
        }
    }
}
