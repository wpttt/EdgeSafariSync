import SwiftUI
import AppKit

@main
struct EdgeSafariSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Sync")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: StatusView())
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
}

struct StatusView: View {
    @State private var syncDirection = "Edge → Safari"
    @State private var statusMessage = "Ready to sync"
    @State private var isSyncing = false
    @State private var statusMessageColor = Color.secondary
    @State private var lastSyncTime: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("EdgeSafari Sync")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Text("Direction:")
                Spacer()
                Text(syncDirection)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            Text(statusMessage)
                .foregroundColor(statusMessageColor)
                .padding(.horizontal)
            
            if let lastSyncTime = lastSyncTime {
                Text("Last sync: \(formatTimestamp(lastSyncTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                Text("Last sync: Never")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Button(action: {
                performSync()
            }) {
                HStack {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isSyncing ? "Syncing..." : "Sync Now")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)
            .padding(.horizontal)
            
            Button("Toggle Direction") {
                toggleDirection()
            }
            .padding(.horizontal)

            Button("Quit App") {
                quitApp()
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(width: 360, height: 400)
    }
    
    func toggleDirection() {
        syncDirection = syncDirection == "Edge → Safari" ? "Safari → Edge" : "Edge → Safari"
    }
    
    func performSync() {
        isSyncing = true
        statusMessage = "Syncing..."
        statusMessageColor = .secondary
        
        Task {
            do {
                if syncDirection == "Edge → Safari" {
                    try syncEdgeToSafari()
                } else {
                    try syncSafariToEdge()
                }
                
                await MainActor.run {
                    isSyncing = false
                    statusMessage = "Sync completed successfully!"
                    statusMessageColor = .green
                    lastSyncTime = Date()
                }
            } catch let error as SyncError {
                await MainActor.run {
                    isSyncing = false
                    if case .permissionDenied = error {
                        statusMessage = "Permission denied. Please grant Full Disk Access."
                        statusMessageColor = .red
                        showPermissionAlert()
                    } else {
                        statusMessage = "Sync failed: \(error.localizedDescription)"
                        statusMessageColor = .red
                    }
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    statusMessage = "Sync failed: \(error.localizedDescription)"
                    statusMessageColor = .red
                }
            }
        }
    }
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要完全磁盘访问权限"
        alert.informativeText = "EdgeSafariSync 需要完全磁盘访问权限才能同步书签。\n\n请在【系统设置 > 隐私与安全性 > 完全磁盘访问权限】中添加并勾选 EdgeSafariSync。"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Full Disk Access
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func formatTimestamp(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // Use relative format for recent syncs (less than 1 hour)
        if timeInterval < 3600 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: now)
        }
        
        // Use absolute format for older syncs
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
