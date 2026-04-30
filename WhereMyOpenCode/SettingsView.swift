import SwiftUI

struct SettingsView: View {
    @State private var rootFolderPath = "Not set"
    @State private var opencodePath = "Auto-detect later"
    @State private var scanDepth = 2

    var body: some View {
        Form {
            Section("Root Folder") {
                LabeledContent("Current", value: rootFolderPath)
                Button("Change...") {}
                    .disabled(true)
            }

            Section("OpenCode") {
                LabeledContent("Binary", value: opencodePath)
                HStack {
                    Button("Change...") {}
                        .disabled(true)
                    Button("Test") {}
                        .disabled(true)
                }
            }

            Section("Scan") {
                Stepper("Depth: \(scanDepth)", value: $scanDepth, in: 1...5)
                    .disabled(true)
            }

            Section("Terminal") {
                LabeledContent("App", value: "Apple Terminal")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
