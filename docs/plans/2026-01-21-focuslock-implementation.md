# FocusLock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that prevents blocked apps from stealing window focus.

**Architecture:** SwiftUI app with MenuBarExtra, event-driven focus monitoring via NSWorkspace notifications, and immediate focus restoration via NSRunningApplication.activate().

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSWorkspace, NSRunningApplication), ServiceManagement (SMAppService), UserNotifications, XcodeGen for project generation.

---

## Prerequisites

Install XcodeGen if not already installed:
```bash
brew install xcodegen
```

---

### Task 1: Project Setup with XcodeGen

**Files:**
- Create: `project.yml`
- Create: `FocusLock/FocusLockApp.swift`
- Create: `FocusLock/Info.plist`
- Create: `FocusLockTests/FocusLockTests.swift`

**Step 1: Create project.yml**

```yaml
name: FocusLock
options:
  bundleIdPrefix: com.focuslock
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
targets:
  FocusLock:
    type: application
    platform: macOS
    sources:
      - FocusLock
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.focuslock.app
        INFOPLIST_FILE: FocusLock/Info.plist
        GENERATE_INFOPLIST_FILE: false
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        ENABLE_HARDENED_RUNTIME: false
    entitlements:
      path: FocusLock/FocusLock.entitlements
      properties:
        com.apple.security.app-sandbox: false
  FocusLockTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - FocusLockTests
    dependencies:
      - target: FocusLock
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.focuslock.tests
        GENERATE_INFOPLIST_FILE: true
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/FocusLock.app/Contents/MacOS/FocusLock"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

**Step 2: Create directory structure**

```bash
mkdir -p FocusLock FocusLockTests
```

**Step 3: Create Info.plist**

Create `FocusLock/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FocusLock</string>
    <key>CFBundleDisplayName</key>
    <string>FocusLock</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

Note: `LSUIElement` = true makes it a menu bar app (no dock icon).

**Step 4: Create entitlements file**

Create `FocusLock/FocusLock.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

**Step 5: Create minimal app entry point**

Create `FocusLock/FocusLockApp.swift`:
```swift
import SwiftUI

@main
struct FocusLockApp: App {
    var body: some Scene {
        MenuBarExtra("FocusLock", systemImage: "lock.fill") {
            Text("FocusLock is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

**Step 6: Create test placeholder**

Create `FocusLockTests/FocusLockTests.swift`:
```swift
import XCTest
@testable import FocusLock

final class FocusLockTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

**Step 7: Generate and build project**

```bash
xcodegen generate
xcodebuild -scheme FocusLock -configuration Debug build
```

Expected: Build succeeds, app appears in `build/Debug/FocusLock.app`

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: initial project setup with XcodeGen

- MenuBarExtra-based SwiftUI app
- LSUIElement for menu bar only (no dock icon)
- XcodeGen for project generation
- Unit test target configured"
```

---

### Task 2: SettingsStore with Blocked Apps

**Files:**
- Create: `FocusLock/Models/BlockedApp.swift`
- Create: `FocusLock/SettingsStore.swift`
- Create: `FocusLockTests/SettingsStoreTests.swift`

**Step 1: Write failing tests for SettingsStore**

Create `FocusLockTests/SettingsStoreTests.swift`:
```swift
import XCTest
@testable import FocusLock

final class SettingsStoreTests: XCTestCase {
    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        // Use a unique suite to avoid polluting real UserDefaults
        let defaults = UserDefaults(suiteName: "com.focuslock.tests")!
        defaults.removePersistentDomain(forName: "com.focuslock.tests")
        store = SettingsStore(defaults: defaults)
    }

    func testDefaultProtectionEnabled() {
        XCTAssertTrue(store.protectionEnabled)
    }

    func testDefaultNotificationsEnabled() {
        XCTAssertTrue(store.notificationsEnabled)
    }

    func testDefaultBlockedAppsContainsSecurityAgent() {
        XCTAssertTrue(store.blockedApps.contains { $0.bundleIdentifier == "com.apple.SecurityAgent" })
    }

    func testAddBlockedApp() {
        let initialCount = store.blockedApps.count
        store.addBlockedApp(bundleIdentifier: "com.example.test", displayName: "Test App")
        XCTAssertEqual(store.blockedApps.count, initialCount + 1)
        XCTAssertTrue(store.blockedApps.contains { $0.bundleIdentifier == "com.example.test" })
    }

    func testRemoveBlockedApp() {
        store.addBlockedApp(bundleIdentifier: "com.example.toremove", displayName: "Remove Me")
        let app = store.blockedApps.first { $0.bundleIdentifier == "com.example.toremove" }!
        store.removeBlockedApp(app)
        XCTAssertFalse(store.blockedApps.contains { $0.bundleIdentifier == "com.example.toremove" })
    }

    func testIsAppBlocked() {
        XCTAssertTrue(store.isAppBlocked(bundleIdentifier: "com.apple.SecurityAgent"))
        XCTAssertFalse(store.isAppBlocked(bundleIdentifier: "com.apple.finder"))
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: FAIL - SettingsStore not found

**Step 3: Create BlockedApp model**

Create `FocusLock/Models/BlockedApp.swift`:
```swift
import Foundation

struct BlockedApp: Codable, Identifiable, Equatable {
    let id: UUID
    let bundleIdentifier: String
    let displayName: String

    init(id: UUID = UUID(), bundleIdentifier: String, displayName: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}
```

**Step 4: Create SettingsStore**

Create `FocusLock/SettingsStore.swift`:
```swift
import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var protectionEnabled: Bool {
        didSet { defaults.set(protectionEnabled, forKey: "protectionEnabled") }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var blockedApps: [BlockedApp] {
        didSet { saveBlockedApps() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load settings with defaults
        self.protectionEnabled = defaults.object(forKey: "protectionEnabled") as? Bool ?? true
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true

        // Load blocked apps or use defaults
        if let data = defaults.data(forKey: "blockedApps"),
           let apps = try? JSONDecoder().decode([BlockedApp].self, from: data) {
            self.blockedApps = apps
        } else {
            self.blockedApps = [
                BlockedApp(bundleIdentifier: "com.apple.SecurityAgent", displayName: "SecurityAgent")
            ]
        }
    }

    private func saveBlockedApps() {
        if let data = try? JSONEncoder().encode(blockedApps) {
            defaults.set(data, forKey: "blockedApps")
        }
    }

    func addBlockedApp(bundleIdentifier: String, displayName: String) {
        guard !isAppBlocked(bundleIdentifier: bundleIdentifier) else { return }
        blockedApps.append(BlockedApp(bundleIdentifier: bundleIdentifier, displayName: displayName))
    }

    func removeBlockedApp(_ app: BlockedApp) {
        blockedApps.removeAll { $0.id == app.id }
    }

    func isAppBlocked(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return blockedApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }
}
```

**Step 5: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add SettingsStore with blocked apps management

- BlockedApp model with Codable support
- SettingsStore with UserDefaults persistence
- Default blocklist includes SecurityAgent
- Add/remove blocked apps functionality
- Unit tests for all settings operations"
```

---

### Task 3: FocusEvent Model and FocusLog

**Files:**
- Create: `FocusLock/Models/FocusEvent.swift`
- Create: `FocusLockTests/FocusEventTests.swift`

**Step 1: Write failing test for FocusEvent**

Create `FocusLockTests/FocusEventTests.swift`:
```swift
import XCTest
@testable import FocusLock

final class FocusEventTests: XCTestCase {
    func testFocusEventCreation() {
        let event = FocusEvent(
            appName: "SecurityAgent",
            bundleIdentifier: "com.apple.SecurityAgent",
            previousAppName: "Terminal",
            wasBlocked: true
        )

        XCTAssertEqual(event.appName, "SecurityAgent")
        XCTAssertEqual(event.bundleIdentifier, "com.apple.SecurityAgent")
        XCTAssertEqual(event.previousAppName, "Terminal")
        XCTAssertTrue(event.wasBlocked)
        XCTAssertNotNil(event.timestamp)
    }

    func testFocusEventFormattedTime() {
        let event = FocusEvent(
            appName: "Test",
            bundleIdentifier: "com.test",
            previousAppName: nil,
            wasBlocked: false
        )

        // Should return HH:mm:ss format
        XCTAssertTrue(event.formattedTime.contains(":"))
        XCTAssertEqual(event.formattedTime.count, 8) // "HH:mm:ss"
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: FAIL - FocusEvent not found

**Step 3: Create FocusEvent model**

Create `FocusLock/Models/FocusEvent.swift`:
```swift
import Foundation

struct FocusEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let bundleIdentifier: String?
    let previousAppName: String?
    var wasBlocked: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appName: String,
        bundleIdentifier: String?,
        previousAppName: String?,
        wasBlocked: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.previousAppName = previousAppName
        self.wasBlocked = wasBlocked
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add FocusEvent model for logging focus changes

- Tracks app name, bundle ID, previous app, timestamp
- wasBlocked flag for blocked events
- Formatted time helper for display"
```

---

### Task 4: FocusMonitor Core Logic

**Files:**
- Create: `FocusLock/FocusMonitor.swift`
- Create: `FocusLockTests/FocusMonitorTests.swift`

**Step 1: Write failing tests for FocusMonitor**

Create `FocusLockTests/FocusMonitorTests.swift`:
```swift
import XCTest
@testable import FocusLock

final class FocusMonitorTests: XCTestCase {
    var monitor: FocusMonitor!
    var settings: SettingsStore!

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: "com.focuslock.tests.monitor")!
        defaults.removePersistentDomain(forName: "com.focuslock.tests.monitor")
        settings = SettingsStore(defaults: defaults)
        monitor = FocusMonitor(settings: settings)
    }

    override func tearDown() {
        monitor.stopMonitoring()
        super.tearDown()
    }

    func testInitialLogIsEmpty() {
        XCTAssertTrue(monitor.log.isEmpty)
    }

    func testLogLimitedTo100Entries() {
        // Simulate adding 110 events
        for i in 0..<110 {
            monitor.addLogEntry(
                appName: "App\(i)",
                bundleIdentifier: "com.test.app\(i)",
                previousAppName: nil,
                wasBlocked: false
            )
        }
        XCTAssertEqual(monitor.log.count, 100)
        // Most recent should be last added
        XCTAssertEqual(monitor.log.first?.appName, "App109")
    }

    func testClearLog() {
        monitor.addLogEntry(appName: "Test", bundleIdentifier: "com.test", previousAppName: nil, wasBlocked: false)
        XCTAssertFalse(monitor.log.isEmpty)
        monitor.clearLog()
        XCTAssertTrue(monitor.log.isEmpty)
    }

    func testShouldBlockApp() {
        XCTAssertTrue(monitor.shouldBlockApp(bundleIdentifier: "com.apple.SecurityAgent"))
        XCTAssertFalse(monitor.shouldBlockApp(bundleIdentifier: "com.apple.finder"))
    }

    func testShouldNotBlockWhenProtectionDisabled() {
        settings.protectionEnabled = false
        XCTAssertFalse(monitor.shouldBlockApp(bundleIdentifier: "com.apple.SecurityAgent"))
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: FAIL - FocusMonitor not found

**Step 3: Create FocusMonitor**

Create `FocusLock/FocusMonitor.swift`:
```swift
import AppKit
import Combine

final class FocusMonitor: ObservableObject {
    @Published var log: [FocusEvent] = []

    private let settings: SettingsStore
    private var previousApp: NSRunningApplication?
    private var currentApp: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private let maxLogEntries = 100

    // Callback for when focus is restored (for notifications)
    var onFocusRestored: ((String, String) -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func startMonitoring() {
        // Initialize current app
        currentApp = NSWorkspace.shared.frontmostApplication

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFocusChange(notification)
        }
    }

    func stopMonitoring() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func handleFocusChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier
        let previousAppName = currentApp?.localizedName

        // Don't log if same app (e.g., window switch within app)
        guard app.processIdentifier != currentApp?.processIdentifier else { return }

        // Check if should block before updating tracking
        let shouldBlock = shouldBlockApp(bundleIdentifier: bundleId)

        // Log the event
        addLogEntry(
            appName: appName,
            bundleIdentifier: bundleId,
            previousAppName: previousAppName,
            wasBlocked: shouldBlock
        )

        if shouldBlock, let prevApp = currentApp {
            // Restore focus to previous app
            restoreFocus(to: prevApp, blockedAppName: appName)
        } else {
            // Update tracking
            previousApp = currentApp
            currentApp = app
        }
    }

    private func restoreFocus(to app: NSRunningApplication, blockedAppName: String) {
        let restoredAppName = app.localizedName ?? "Unknown"

        // Use modern activation API
        if #available(macOS 14.0, *) {
            NSRunningApplication.current.yieldActivation(toApplicationWithBundleIdentifier: app.bundleIdentifier ?? "")
        }
        app.activate()

        onFocusRestored?(blockedAppName, restoredAppName)
    }

    func shouldBlockApp(bundleIdentifier: String?) -> Bool {
        guard settings.protectionEnabled else { return false }
        return settings.isAppBlocked(bundleIdentifier: bundleIdentifier)
    }

    func addLogEntry(appName: String, bundleIdentifier: String?, previousAppName: String?, wasBlocked: Bool) {
        let event = FocusEvent(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            previousAppName: previousAppName,
            wasBlocked: wasBlocked
        )

        log.insert(event, at: 0)

        // Trim to max entries
        if log.count > maxLogEntries {
            log = Array(log.prefix(maxLogEntries))
        }
    }

    func clearLog() {
        log.removeAll()
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add FocusMonitor for focus detection and restoration

- Subscribes to NSWorkspace.didActivateApplicationNotification
- Tracks previous/current app for restoration
- Blocks apps from settings blocklist
- Maintains rolling log of 100 events
- Uses modern macOS 14+ activation API with fallback"
```

---

### Task 5: NotificationManager

**Files:**
- Create: `FocusLock/NotificationManager.swift`

**Step 1: Create NotificationManager**

Create `FocusLock/NotificationManager.swift`:
```swift
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
```

**Step 2: Build to verify no errors**

```bash
xcodegen generate && xcodebuild -scheme FocusLock -configuration Debug build
```

Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add NotificationManager for focus restoration alerts

- Requests notification permission on demand
- Tracks permission status
- Sends silent visual notification when focus restored"
```

---

### Task 6: Menu Bar UI

**Files:**
- Modify: `FocusLock/FocusLockApp.swift`

**Step 1: Update FocusLockApp with full menu**

Replace `FocusLock/FocusLockApp.swift`:
```swift
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
```

**Step 2: Build to verify no errors (views don't exist yet)**

```bash
xcodegen generate && xcodebuild -scheme FocusLock -configuration Debug build 2>&1 | head -50
```

Expected: Build fails - LogWindowView and BlockedAppsView not found

**Step 3: Commit partial progress**

```bash
git add -A
git commit -m "feat: update app entry point with menu bar UI structure

- Toggle for protection and notifications
- Launch at login via SMAppService
- Window scenes for log and blocked apps (views pending)"
```

---

### Task 7: Log Window View

**Files:**
- Create: `FocusLock/Views/LogWindowView.swift`

**Step 1: Create LogWindowView**

Create `FocusLock/Views/LogWindowView.swift`:
```swift
import SwiftUI

struct LogWindowView: View {
    @ObservedObject var monitor: FocusMonitor
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Focus Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    monitor.clearLog()
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Log entries
            if monitor.log.isEmpty {
                Spacer()
                Text("No focus changes recorded yet")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(monitor.log) { event in
                    LogEntryRow(event: event, settings: settings)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct LogEntryRow: View {
    let event: FocusEvent
    @ObservedObject var settings: SettingsStore

    private var isAlreadyBlocked: Bool {
        guard let bundleId = event.bundleIdentifier else { return false }
        return settings.isAppBlocked(bundleIdentifier: bundleId)
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.formattedTime)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(event.appName)
                        .fontWeight(.medium)

                    if event.wasBlocked {
                        Text("blocked")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }

                if let previous = event.previousAppName {
                    Text("← \(previous)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Add to blocklist button
            if let bundleId = event.bundleIdentifier, !isAlreadyBlocked {
                Button {
                    settings.addBlockedApp(bundleIdentifier: bundleId, displayName: event.appName)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Add to blocklist")
            }
        }
        .padding(.vertical, 4)
    }
}
```

**Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme FocusLock -configuration Debug build 2>&1 | head -50
```

Expected: Build fails - BlockedAppsView not found

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add LogWindowView for focus event history

- Displays timestamped focus changes
- Shows blocked status for intercepted events
- One-click add to blocklist from log entries
- Clear log functionality"
```

---

### Task 8: Blocked Apps View

**Files:**
- Create: `FocusLock/Views/BlockedAppsView.swift`

**Step 1: Create BlockedAppsView**

Create `FocusLock/Views/BlockedAppsView.swift`:
```swift
import SwiftUI

struct BlockedAppsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var newBundleId = ""
    @State private var newDisplayName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Blocked Apps")
                .font(.headline)
                .padding()

            Divider()

            // List of blocked apps
            List {
                ForEach(settings.blockedApps) { app in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(app.displayName)
                                .fontWeight(.medium)
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            settings.removeBlockedApp(app)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            Divider()

            // Add new app
            VStack(alignment: .leading, spacing: 8) {
                Text("Add App")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Bundle Identifier (e.g., com.example.app)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)

                TextField("Display Name", text: $newDisplayName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Add") {
                        guard !newBundleId.isEmpty else { return }
                        let displayName = newDisplayName.isEmpty ? newBundleId : newDisplayName
                        settings.addBlockedApp(bundleIdentifier: newBundleId, displayName: displayName)
                        newBundleId = ""
                        newDisplayName = ""
                    }
                    .disabled(newBundleId.isEmpty)
                }
            }
            .padding()
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}
```

**Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme FocusLock -configuration Debug build
```

Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add BlockedAppsView for managing blocklist

- List view of all blocked apps
- Delete button per entry
- Add new apps by bundle ID
- Display name optional (defaults to bundle ID)"
```

---

### Task 9: Wire Up Focus Monitoring and Notifications

**Files:**
- Modify: `FocusLock/FocusLockApp.swift`

**Step 1: Update FocusLockApp to start monitoring and connect notifications**

Replace `FocusLock/FocusLockApp.swift`:
```swift
import SwiftUI
import ServiceManagement

@main
struct FocusLockApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var focusMonitor: FocusMonitor
    @StateObject private var notificationManager = NotificationManager()

    @Environment(\.openWindow) private var openWindow

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _focusMonitor = StateObject(wrappedValue: FocusMonitor(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra("FocusLock", systemImage: "lock.fill") {
            Toggle("Protection Enabled", isOn: $settings.protectionEnabled)

            Toggle("Notifications", isOn: $settings.notificationsEnabled)
                .onChange(of: settings.notificationsEnabled) { _, newValue in
                    if newValue && !notificationManager.permissionGranted {
                        notificationManager.requestPermission()
                    }
                }

            Divider()

            Button("View Focus Log...") {
                openWindow(id: "log")
            }

            Button("Blocked Apps...") {
                openWindow(id: "blocked-apps")
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
        .menuBarExtraStyle(.menu)

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

// App delegate to handle lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    var focusMonitor: FocusMonitor?
    var notificationManager: NotificationManager?
    var settings: SettingsStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start monitoring when app launches
        focusMonitor?.startMonitoring()

        // Connect notification callback
        focusMonitor?.onFocusRestored = { [weak self] blockedApp, restoredApp in
            guard let self, let settings = self.settings else { return }
            if settings.notificationsEnabled {
                self.notificationManager?.sendNotification(blockedApp: blockedApp, restoredApp: restoredApp)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor?.stopMonitoring()
    }
}
```

Wait - SwiftUI apps don't use AppDelegate by default. Let me fix this with a proper approach.

**Step 1 (revised): Update FocusLockApp with proper lifecycle handling**

Replace `FocusLock/FocusLockApp.swift`:
```swift
import SwiftUI
import ServiceManagement

@main
struct FocusLockApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var focusMonitor: FocusMonitor
    @StateObject private var notificationManager = NotificationManager()

    @Environment(\.openWindow) private var openWindow

    init() {
        let settingsInstance = SettingsStore()
        let monitorInstance = FocusMonitor(settings: settingsInstance)

        _settings = StateObject(wrappedValue: settingsInstance)
        _focusMonitor = StateObject(wrappedValue: monitorInstance)

        // Start monitoring immediately
        monitorInstance.startMonitoring()
    }

    var body: some Scene {
        MenuBarExtra("FocusLock", systemImage: "lock.fill") {
            MenuContent(
                settings: settings,
                notificationManager: notificationManager,
                openWindow: openWindow
            )
        }
        .menuBarExtraStyle(.menu)

        Window("Focus Log", id: "log") {
            LogWindowView(monitor: focusMonitor, settings: settings)
        }
        .defaultSize(width: 500, height: 400)

        Window("Blocked Apps", id: "blocked-apps") {
            BlockedAppsView(settings: settings)
        }
        .defaultSize(width: 400, height: 300)
    }
}

struct MenuContent: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var notificationManager: NotificationManager
    let openWindow: OpenWindowAction

    var body: some View {
        Toggle("Protection Enabled", isOn: $settings.protectionEnabled)

        Toggle("Notifications", isOn: $settings.notificationsEnabled)
            .onChange(of: settings.notificationsEnabled) { _, newValue in
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

        Toggle("Launch at Login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
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
        ))

        Divider()

        Button("Quit FocusLock") {
            NSApplication.shared.terminate(nil)
        }
    }
}
```

**Step 2: Update FocusMonitor to wire notifications in init**

Add to `FocusLock/FocusMonitor.swift` - update the class to accept notification manager:

Actually, let's keep it simple and use a different approach. Update `FocusLockApp.swift` with an AppDelegate adapter:

```swift
import SwiftUI
import ServiceManagement

@main
struct FocusLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("FocusLock", systemImage: "lock.fill") {
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

        focusMonitor.onFocusRestored = { [weak self] blockedApp, restoredApp in
            guard let self else { return }
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

    var body: some View {
        Toggle("Protection Enabled", isOn: $settings.protectionEnabled)

        Toggle("Notifications", isOn: $settings.notificationsEnabled)
            .onChange(of: settings.notificationsEnabled) { _, newValue in
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

        Toggle("Launch at Login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
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
        ))

        Divider()

        Button("Quit FocusLock") {
            NSApplication.shared.terminate(nil)
        }
    }
}
```

**Step 2: Build and test**

```bash
xcodegen generate && xcodebuild -scheme FocusLock -configuration Debug build
```

Expected: Build succeeds

**Step 3: Run tests**

```bash
xcodebuild -scheme FocusLockTests -configuration Debug test
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire up focus monitoring and notifications

- AppDelegate handles app lifecycle
- Starts monitoring on launch
- Connects focus restoration to notifications
- Proper cleanup on termination"
```

---

### Task 10: Final Integration Test

**Step 1: Build release version**

```bash
xcodegen generate && xcodebuild -scheme FocusLock -configuration Release build
```

**Step 2: Locate and run the app**

```bash
open build/Release/FocusLock.app
```

**Step 3: Manual testing checklist**

- [ ] App appears in menu bar with lock icon
- [ ] Clicking icon shows menu with all options
- [ ] Protection toggle works
- [ ] Notifications toggle works (requests permission if needed)
- [ ] "View Focus Log..." opens log window
- [ ] "Blocked Apps..." opens blocked apps window
- [ ] Can add/remove apps from blocklist
- [ ] Focus changes appear in log
- [ ] SecurityAgent focus stealing is blocked (if you can trigger it)
- [ ] "Launch at Login" toggle works
- [ ] "Quit" terminates the app

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: complete FocusLock v1.0 implementation

All features implemented:
- Focus monitoring via NSWorkspace notifications
- Automatic focus restoration for blocked apps
- Configurable blocklist (default: SecurityAgent)
- Optional notifications
- Focus event log with one-click blocking
- Launch at login support
- Menu bar UI"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Project setup with XcodeGen | project.yml, Info.plist, entitlements |
| 2 | SettingsStore with blocked apps | SettingsStore.swift, BlockedApp.swift |
| 3 | FocusEvent model | FocusEvent.swift |
| 4 | FocusMonitor core logic | FocusMonitor.swift |
| 5 | NotificationManager | NotificationManager.swift |
| 6 | Menu bar UI structure | FocusLockApp.swift |
| 7 | Log window view | LogWindowView.swift |
| 8 | Blocked apps view | BlockedAppsView.swift |
| 9 | Wire up monitoring + notifications | FocusLockApp.swift |
| 10 | Final integration test | - |
