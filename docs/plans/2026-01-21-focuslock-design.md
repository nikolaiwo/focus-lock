# FocusLock Design Document

A lightweight macOS menu bar utility that prevents unwanted apps from stealing window focus.

## Problem

SecurityAgent (and potentially other apps) steal window focus unexpectedly, interrupting workflow. This app automatically restores focus to the previous window when a blocked app activates.

## Requirements

- macOS 13+ (Ventura and later)
- Detect when blocked apps steal focus
- Immediately restore focus to previous app
- Configurable blocklist (default: SecurityAgent)
- Optional notifications when focus is restored
- Focus event log for debugging
- Launch at login support
- Menu bar app (no dock icon)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    FocusLockApp                     │
│                   (SwiftUI App)                     │
├─────────────────────────────────────────────────────┤
│  MenuBarExtra        │  FocusMonitor               │
│  - Icon display      │  - Listens for focus events │
│  - Settings menu     │  - Tracks previous app      │
│  - Toggle controls   │  - Restores focus           │
│  - "View Log" option │  - Logs all focus changes   │
├──────────────────────┼──────────────────────────────┤
│  SettingsStore       │  NotificationManager        │
│  - Blocked apps list │  - Shows restoration alerts │
│  - Notifications on  │  - Respects user preference │
│  - Protection on     │                             │
│  - Launch at login   │                             │
├──────────────────────┴──────────────────────────────┤
│  FocusLog                                           │
│  - Recent focus changes (last 100 entries)          │
│  - Timestamp, app name, whether it was blocked      │
│  - "Add to blocklist" button per entry              │
└─────────────────────────────────────────────────────┘
```

## File Structure

```
FocusLock/
├── FocusLock.xcodeproj/
├── FocusLock/
│   ├── FocusLockApp.swift       # App entry point + MenuBarExtra
│   ├── FocusMonitor.swift       # Focus detection & restoration
│   ├── SettingsStore.swift      # Persisted settings
│   ├── NotificationManager.swift
│   ├── Views/
│   │   ├── LogWindow.swift      # Focus event log view
│   │   └── BlockedAppsWindow.swift
│   └── Assets.xcassets/         # Menu bar icon
└── docs/
    └── plans/
```

## Core Components

### FocusMonitor

Subscribes to `NSWorkspace.didActivateApplicationNotification` for event-driven focus detection.

```swift
class FocusMonitor: ObservableObject {
    @Published var log: [FocusEvent] = []

    private var previousApp: NSRunningApplication?
    private var currentApp: NSRunningApplication?

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFocusChange(notification)
        }
    }
}
```

**Focus change handling:**

1. Extract newly activated app from notification
2. Log the event (timestamp, app name, previous app)
3. Check if new app's bundle identifier is in blocklist
4. If blocked AND protection enabled:
   - Call `previousApp?.activate()` to restore focus
   - Mark log entry as "blocked"
   - Send notification if enabled
5. Update tracking: `previousApp = currentApp`, `currentApp = newApp`

**Blocklist matching:** By bundle identifier (e.g., `com.apple.SecurityAgent`), not display name.

### SettingsStore

```swift
class SettingsStore: ObservableObject {
    @AppStorage("protectionEnabled") var protectionEnabled = true
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("blockedApps") var blockedAppsData: Data = Data()

    var blockedApps: [BlockedApp]  // Computed from blockedAppsData
}

struct BlockedApp: Codable, Identifiable {
    let id: UUID
    let bundleIdentifier: String
    let displayName: String
}
```

**Default blocklist:** `com.apple.SecurityAgent`

**Launch at login:** Uses `SMAppService.mainApp.register()` / `.unregister()`

### NotificationManager

Uses `UserNotifications` framework. Requests permission on first launch.

Notification content:
- Title: "Blocked [AppName]"
- Body: "Restored focus to [PreviousApp]"

## User Interface

### Menu Bar

```
[🔒] ← Icon (click to open menu)
 ├─ ✓ Protection Enabled      (toggle)
 ├─ ✓ Notifications           (toggle)
 ├─ ───────────────────
 ├─ View Focus Log...         (opens window)
 ├─ Blocked Apps...           (opens window)
 ├─ ───────────────────
 ├─ ✓ Launch at Login         (toggle)
 ├─ Quit FocusLock
```

Icon: `lock.fill` SF Symbol

### Log Window

```
┌─────────────────────────────────────────────────┐
│ Focus Log                               [Clear] │
├─────────────────────────────────────────────────┤
│ 14:32:01  SecurityAgent        [blocked]   [+] │
│           ← Terminal                           │
│ 14:31:45  Finder                           [+] │
│           ← VS Code                            │
│ 14:30:22  Terminal                         [+] │
│           ← Safari                             │
└─────────────────────────────────────────────────┘
```

- `[blocked]` tag when focus was restored
- `[+]` button adds app to blocklist
- Last 100 events, clears on restart

### Blocked Apps Window

List with delete button per entry, plus text field to add by bundle ID.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Previous app quit | Skip restoration silently |
| `activate()` fails | Log failure, don't retry |
| Notification permission denied | Disable toggle, show note |
| Launch at login fails | Show alert, revert toggle |
| Unknown app (no bundle ID) | Log with "Unknown", allow blocking by process name |

## Permissions

No special permissions required. `NSWorkspace` notifications and `NSRunningApplication.activate()` work without Accessibility entitlements.

## Development Workflow

Edit Swift files in any editor, build via command line:

```bash
xcodebuild -scheme FocusLock -configuration Release build
```

Xcode GUI only needed for initial project setup (bundle ID, deployment target, entitlements).

## Out of Scope (v1)

- Scheduling / time-based rules
- Per-app conditional rules
- Statistics / analytics
- Automatic updates
- Dock icon mode
