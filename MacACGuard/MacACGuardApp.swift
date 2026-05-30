import AppKit
import Darwin
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        MacACGuardApp.instanceLock?.release()
    }
}

@main
struct MacACGuardApp: App {
    static var instanceLock: SingleInstanceLock?

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        let logger = EventLogger()
        do {
            Self.instanceLock = try SingleInstanceLock.acquire()
        } catch SingleInstanceLockError.alreadyRunning {
            logger.log(.duplicateInstance, "Another MacACGuard instance is already running. Exiting.")
            Darwin.exit(0)
        } catch {
            logger.log(.error, "MacACGuard failed to acquire single-instance lock: \(error.localizedDescription)")
            Darwin.exit(1)
        }
        _appState = StateObject(wrappedValue: AppState(logger: logger))
    }

    var body: some Scene {
        MenuBarExtra("Mac AC Guard", systemImage: "bolt.shield") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 440)
                .padding()
        }
    }
}
