import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.shield", accessibilityDescription: "Mac AC Guard")
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 520, height: 700)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(appState)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(relativeTo: sender)
        } else {
            togglePopover(relativeTo: sender)
        }
    }

    func showPopover(tab: AppTab = .status) {
        appState.selectedTab = tab
        appState.refreshStatus()
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            appState.setPopoverPresented(true)
            activatePopoverWindow()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        appState.setPopoverPresented(false)
    }

    func popoverDidClose(_ notification: Notification) {
        appState.setPopoverPresented(false)
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        popover.isShown ? closePopover() : showPopover()
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        }
        let menu = NSMenu()
        menu.addItem(menuItem(.openMacACGuard, action: #selector(openMainPopover)))
        menu.addItem(menuItem(.refreshStatus, action: #selector(refreshStatus)))
        menu.addItem(.separator())
        menu.addItem(menuItem(.batteryLab, action: #selector(openBatteryLab)))
        menu.addItem(menuItem(.diagnostics, action: #selector(openDiagnostics)))
        menu.addItem(.separator())
        menu.addItem(menuItem(.quitMacACGuard, action: #selector(quitApp)))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
    }

    private func menuItem(_ key: L10nKey, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: appState.text(key), action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openMainPopover() {
        showPopover(tab: .status)
    }

    @objc private func refreshStatus() {
        appState.refreshStatus()
    }

    @objc private func openBatteryLab() {
        showPopover(tab: .lab)
    }

    @objc private func openDiagnostics() {
        showPopover(tab: .settings)
    }

    @objc private func quitApp() {
        closePopover()
        appState.prepareForTermination()
        MacACGuardApp.releaseInstanceLock()
        NSApplication.shared.terminate(nil)
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        if popover.isShown {
            closePopover()
        }
    }

    private func activatePopoverWindow() {
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.popover.isShown else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.popover.contentViewController?.view.window?.makeKey()
        }
    }
}
