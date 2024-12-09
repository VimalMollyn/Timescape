import SwiftUI
import ServiceManagement

struct SettingsView: View {
    private let logFilePath: String = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app_usage.log").path
    }()
    @State private var showAlert = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Log File Location")
                .font(.headline)
            
            HStack {
                TextField("Log File Path", text: .constant(logFilePath))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
                
                Button("Show in Finder") {
                    // Create the file if it doesn't exist
                    if !FileManager.default.fileExists(atPath: logFilePath) {
                        do {
                            try "App Usage Log\n".write(to: URL(fileURLWithPath: logFilePath), atomically: true, encoding: .utf8)
                        } catch {
                            print("Error creating log file: \(error)")
                            return
                        }
                    }
                    
                    // Now show it in Finder
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: logFilePath)])
                }
            }
            
            Text("Log file is stored in Application Support directory")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        try SMAppService.mainApp.register()
                    } catch {
                        print("Failed to register app for launch at login: \(error)")
                        launchAtLogin = false
                    }
                }
            
            Divider()
            
            Button("Clear App Usage Log") {
                showAlert = true
            }
            .alert("Clear App Usage Log?", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAppUsageLog()
                }
            } message: {
                Text("This will archive the current log and start a new one. This action cannot be undone.")
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 150)
        .onAppear {
            // Update toggle state based on current registration
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func clearAppUsageLog() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let currentLogURL = appSupport.appendingPathComponent("app_usage.log")
        
        do {
            // Create backup filename with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let backupURL = appSupport.appendingPathComponent("app_usage_\(timestamp).log")
            
            // If current log exists, move it to backup
            if fileManager.fileExists(atPath: currentLogURL.path) {
                try fileManager.moveItem(at: currentLogURL, to: backupURL)
            }
            
            // Create new log file
            try "App Usage Log\n".write(to: currentLogURL, atomically: true, encoding: .utf8)
            
            // Post notification to update any observers
            NotificationCenter.default.post(name: NSNotification.Name("AppUsageLogCleared"), object: nil)
            
        } catch {
            print("Error clearing log file: \(error)")
        }
    }
} 