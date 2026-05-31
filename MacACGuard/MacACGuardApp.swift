import AppKit
import Darwin
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController(appState: MacACGuardApp.sharedAppState)
    }

    func applicationWillTerminate(_ notification: Notification) {
        MacACGuardApp.sharedAppState.prepareForTermination()
        MacACGuardApp.releaseInstanceLock()
    }
}

@main
struct MacACGuardApp: App {
    static var instanceLock: SingleInstanceLock?
    static var sharedAppState: AppState!

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

        let state = AppState(logger: logger)
        Self.sharedAppState = state
        _appState = StateObject(wrappedValue: state)
    }

    static func releaseInstanceLock() {
        instanceLock?.release()
        instanceLock = nil
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 520)
                .padding(10)
                .background(.regularMaterial)
        }
    }
}
