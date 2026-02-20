import Cocoa
import Combine

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private let spaceKeyCode: UInt16 = 49 // Space key
    private var isManualDucking = false
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Global monitor (works anywhere in macOS as long as Accessibility is granted)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor (works if our menu window is frontmost)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == spaceKeyCode {
            if event.type == .keyDown && event.modifierFlags.contains(.control) {
                if !isManualDucking {
                    isManualDucking = true
                    DispatchQueue.main.async {
                        AudioDucker.shared.startDucking()
                    }
                }
            } else if event.type == .keyUp {
                if isManualDucking {
                    isManualDucking = false
                    DispatchQueue.main.async {
                        AudioDucker.shared.stopDucking()
                    }
                }
            }
        }
    }
    
    deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
