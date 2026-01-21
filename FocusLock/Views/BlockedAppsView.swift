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
