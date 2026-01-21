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
