import MacEnvCore
import SwiftUI

@main
struct MacEnvManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = EnvironmentViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Mac Env Manager", id: "main") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1120, minHeight: 720)
                .task {
                    await viewModel.loadAsync()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("重新加载") {
                    viewModel.reload()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("写入待处理更改") {
                    viewModel.applyChanges()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }

        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchPolicy = LaunchPolicy()

    func applicationDidFinishLaunching(_ notification: Notification) {
        activate()
    }

    private func activate() {
        if launchPolicy.activationPolicy == .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        NSApplication.shared.activate(ignoringOtherApps: launchPolicy.activatesIgnoringOtherApps)
    }
}
