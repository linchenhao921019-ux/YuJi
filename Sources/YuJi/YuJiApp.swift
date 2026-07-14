import AppKit
import SwiftUI

@main
struct YuJiApp: App {
    @StateObject private var store = ScanStore()

    init() {
        NSApplication.shared.appearance = nil
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("余迹") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 880)
        .commands {
            CommandGroup(after: .newItem) {
                Button(store.hasStartedScan ? "重新扫描" : "开始扫描") { store.startScan() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("导出扫描报告…") { store.exportReport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
