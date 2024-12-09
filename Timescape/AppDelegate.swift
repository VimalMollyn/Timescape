import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var settingsWindow: NSWindow?
    private let fileManager = FileManager.default
    private var logPathObserver: NSObjectProtocol?
    private var usageWindow: NSWindow?
    private var logClearedObserver: NSObjectProtocol?
    private var powerNotificationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    
    private lazy var logFileURL: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = appSupport.appendingPathComponent("app_usage.log")
        // print("Using log file path: \(url.path)")
        return url
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Running Applications:", action: nil, keyEquivalent: ""))
            statusItem?.menu = menu
            
            // Initial update
            updateStatusBarTitle()
        }
        
        // Observe app switching
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusBarTitle()
        }
        
        // Add observer for log file path changes
        logPathObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if UserDefaults.standard.object(forKey: "logFilePath") != nil {
                print("Log file path updated")
                // You might want to migrate existing logs here if needed
            }
        }
        
        // Add observer for log cleared notification
        logClearedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppUsageLogCleared"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Refresh any views or data that depend on the log file
            print("Log file cleared and recreated")
        }
        
        // Observe system sleep/wake
        powerNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logSystemEvent(event: "System Sleep")
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logSystemEvent(event: "System Wake")
        }
        
        // Observe app termination (which could be from shutdown/restart)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logSystemEvent(event: "System Shutdown/Restart")
        }
    }
    
    deinit {
        if let observer = logPathObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = logClearedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = powerNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateStatusBarTitle() {
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            let appName = currentApp.localizedName ?? "Unknown"
            statusItem?.button?.title = " \(appName)"
            
            // Log app switch
            logAppSwitch(appName: appName)
            
            // Update menu items
            if let menu = statusItem?.menu {
                // Remove all items
                menu.removeAllItems()
                
                // Create Running Apps submenu
                let runningAppsMenu = NSMenu()
                let runningAppsItem = NSMenuItem(title: "Running Apps", action: nil, keyEquivalent: "")
                runningAppsItem.submenu = runningAppsMenu
                
                // Add running apps to submenu
                for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                    let item = NSMenuItem(title: app.localizedName ?? "Unknown", action: nil, keyEquivalent: "")
                    item.attributedTitle = NSAttributedString(
                        string: app.localizedName ?? "Unknown",
                        attributes: [
                            .foregroundColor: NSColor.labelColor,
                            .font: NSFont.menuBarFont(ofSize: 13)
                        ]
                    )
                    runningAppsMenu.addItem(item)
                }
                
                // Add items to main menu
                menu.addItem(runningAppsItem)
                menu.addItem(NSMenuItem.separator())
                
                // Add View Usage item
                // let usageItem = NSMenuItem(title: "View Usage", action: #selector(openUsage), keyEquivalent: "")
                // usageItem.target = self
                // menu.addItem(usageItem)
                
                // Add settings and quit items
                let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "")
                settingsItem.target = self
                menu.addItem(settingsItem)
                
                menu.addItem(NSMenuItem.separator())
                let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
                quitItem.target = NSApp
                menu.addItem(quitItem)
            }
        }
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Settings"
            window.contentView = NSHostingView(rootView: SettingsView())
            
            // Set close behavior to hide instead of close
            window.isReleasedWhenClosed = false
            
            // Handle the close button
            window.standardWindowButton(.closeButton)?.target = self
            window.standardWindowButton(.closeButton)?.action = #selector(hideSettingsWindow)
            
            // Make window level floating and set behavior
            window.level = .floating
            window.collectionBehavior = [.managed, .fullScreenAuxiliary]
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func hideSettingsWindow() {
        settingsWindow?.orderOut(nil)
        // Switch back to accessory mode after hiding
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    @objc func openUsage() {
        if usageWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Usage Statistics"
            window.contentView = NSHostingView(rootView: ContentView())
            window.minSize = NSSize(width: 600, height: 400)  // Set minimum size
            
            // Set close behavior to hide instead of close
            window.isReleasedWhenClosed = false
            
            // Handle the close button
            window.standardWindowButton(.closeButton)?.target = self
            window.standardWindowButton(.closeButton)?.action = #selector(hideUsageWindow)
            
            // Make window level floating
            window.level = .floating
            window.collectionBehavior = [.managed, .fullScreenAuxiliary]
            
            usageWindow = window
        }
        
        usageWindow?.makeKeyAndOrderFront(nil)
        usageWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func hideUsageWindow() {
        usageWindow?.orderOut(nil)
    }
    
    private func logAppSwitch(appName: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "\(timestamp),\(appName)\n"
        
        do {
            // Create directory if it doesn't exist
            let directory = logFileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Created directory at: \(directory.path)")
            }
            
            // Create file if it doesn't exist
            if !fileManager.fileExists(atPath: logFileURL.path) {
                print("Creating new log file at: \(logFileURL.path)")
                try "App Usage Log\n".write(to: logFileURL, atomically: true, encoding: .utf8)
            }
            
            let handle = try FileHandle(forWritingTo: logFileURL)
            handle.seekToEndOfFile()
            handle.write(logEntry.data(using: .utf8)!)
            handle.closeFile()
        } catch {
            print("Error writing to log file: \(error)")
        }
    }
    
    private func logSystemEvent(event: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "\(timestamp),[\(event)]\n"
        
        do {
            // Create directory if it doesn't exist
            let directory = logFileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            // Create file if it doesn't exist
            if !fileManager.fileExists(atPath: logFileURL.path) {
                try "App Usage Log\n".write(to: logFileURL, atomically: true, encoding: .utf8)
            }
            
            let handle = try FileHandle(forWritingTo: logFileURL)
            handle.seekToEndOfFile()
            handle.write(logEntry.data(using: .utf8)!)
            handle.closeFile()
        } catch {
            print("Error writing system event to log file: \(error)")
        }
    }
} 
