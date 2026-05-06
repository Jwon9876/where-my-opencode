import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    @State private var opencodeStatusMessage: String?
    @State private var opencodeStatusIsError = false

    private let openCodeLauncher = OpenCodeLauncher()

    var body: some View {
        Form {
            Section("Root Folder") {
                LabeledContent("Current", value: rootFolderDisplayValue)
                Button("Change...") {
                    chooseRootFolder()
                }
            }

            Section("OpenCode") {
                LabeledContent("Binary", value: opencodeDisplayValue)
                HStack {
                    Button("Change...") {
                        chooseOpenCodeBinary()
                    }
                    Button("Test") {
                        testOpenCodeConfiguration()
                    }
                }

                if let opencodeStatusMessage {
                    Text(opencodeStatusMessage)
                        .font(.caption)
                        .foregroundStyle(opencodeStatusIsError ? .red : .secondary)
                }
            }

            Section("Terminal") {
                Picker("App", selection: terminalAppBinding) {
                    ForEach(TerminalApp.allCases) { terminalApp in
                        Text(terminalApp.displayName)
                            .tag(terminalApp)
                    }
                }
            }

            if let lastErrorMessage = settingsStore.lastErrorMessage {
                Section("Status") {
                    Text(lastErrorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var rootFolderDisplayValue: String {
        settingsStore.settings.rootFolderPath ?? "Not set"
    }

    private var opencodeDisplayValue: String {
        settingsStore.settings.opencodePath ?? "Auto-detect later"
    }

    private var terminalAppBinding: Binding<TerminalApp> {
        Binding(
            get: { settingsStore.settings.terminalApp },
            set: { settingsStore.setTerminalApp($0) }
        )
    }

    private func chooseRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Project Root Folder"
        panel.message = "Choose the folder where your projects live."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {
            settingsStore.setRootFolderPath(panel.url?.path)
        }
    }

    private func chooseOpenCodeBinary() {
        let panel = NSOpenPanel()
        panel.title = "Choose OpenCode Binary"
        panel.message = "Choose the opencode executable."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {
            settingsStore.setOpenCodePath(panel.url?.path)
            opencodeStatusMessage = nil
        }
    }

    private func testOpenCodeConfiguration() {
        do {
            opencodeStatusMessage = try openCodeLauncher.checkConfiguration(settings: settingsStore.settings)
            opencodeStatusIsError = false
        } catch {
            opencodeStatusMessage = error.localizedDescription
            opencodeStatusIsError = true
        }
    }
}
