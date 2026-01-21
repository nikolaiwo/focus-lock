import SwiftUI
import ServiceManagement

@main
struct FocusLockApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var focusMonitor: FocusMonitor
    @StateObject private var notificationManager = NotificationManager()

    @State private var showingLog = false
    @State private var showingBlockedApps = false

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _focusMonitor = StateObject(wrappedValue: FocusMonitor(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra("FocusLock", systemImage: "lock.fill") {
            Toggle("Protection Enabled", isOn: $settings.protectionEnabled)
            Toggle("Notifications", isOn: $settings.notificationsEnabled)
                .disabled(!notificationManager.permissionGranted)

            Divider()

            Button("View Focus Log...") {
                showingLog = true
            }

            Button("Blocked Apps...") {
                showingBlockedApps = true
            }

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { setLaunchAtLogin($0) }
            ))

            Divider()

            Button("Quit FocusLock") {
                NSApplication.shared.terminate(nil)
            }
        }

        Window("Focus Log", id: "log") {
            LogWindowView(monitor: focusMonitor, settings: settings)
        }
        .defaultSize(width: 500, height: 400)

        Window("Blocked Apps", id: "blocked-apps") {
            BlockedAppsView(settings: settings)
        }
        .defaultSize(width: 400, height: 300)
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}
