import SwiftUI
import ApplicationServices

@main
struct MinMicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("MinMic", systemImage: "mic.slash.circle") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permissions required for global hotkeys
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Warning: Accessibility permissions not granted. Global hotkeys may not work.")
        }
        
        // Start monitoring mic for Voice Activity
        MicMonitor.shared.startMonitoring()
    }
}
