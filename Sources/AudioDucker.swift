import Foundation
import CoreAudio
import Combine

class AudioDucker: ObservableObject {
    static let shared = AudioDucker()

    @Published var isDucking: Bool = false
    @Published var activeDeviceName: String = "Discovering..."

    private var duckingPercentage: Double = 0.5
    private var savedSystemVolume: Int = -1

    init() {
        updateActiveDeviceName()
        startListeningToDeviceChanges()
    }

    func updateDuckingPercentage(_ percentage: Double) {
        self.duckingPercentage = percentage
        if isDucking {
            stopDucking()
            startDucking()
        }
    }

    func startDucking() {
        if isDucking { return }
        isDucking = true
        updateActiveDeviceName()
        savedSystemVolume = readSystemVolume()
        runDuckScript()
    }

    func stopDucking() {
        if !isDucking { return }
        isDucking = false
        runRestoreScript()
        savedSystemVolume = -1
    }

    // MARK: - AppleScript

    private func runDuckScript() {
        let appPercent = Int((1.0 - duckingPercentage) * 100)  // 0-100 for Spotify/Music
        let factor = 1.0 - duckingPercentage                    // 0.0-1.0 multiplier for JS

        // JS: save each element's volume in a data attribute, then scale it down
        let duckJS = "(function(){document.querySelectorAll('audio,video').forEach(function(e){if(e.dataset.mm===undefined){e.dataset.mm=e.volume;e.volume=Math.max(0,e.volume*\(factor));}});})();"

        let sysVol = savedSystemVolume >= 0
            ? Int(Double(savedSystemVolume) * (1.0 - duckingPercentage))
            : appPercent

        let script = """
        -- System volume (works on most built-in/wired devices)
        try
            set volume output volume \(sysVol)
        end try

        -- Browser audio via JavaScript (HTML5 audio/video elements)
        try
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            try
                                execute t javascript "\(duckJS)"
                            end try
                        end repeat
                    end repeat
                end tell
            end if
        end try
        try
            if application "Arc" is running then
                tell application "Arc"
                    repeat with w in windows
                        repeat with t in tabs of w
                            try
                                execute t javascript "\(duckJS)"
                            end try
                        end repeat
                    end repeat
                end tell
            end if
        end try
        try
            if application "Safari" is running then
                tell application "Safari"
                    repeat with w in windows
                        repeat with t in tabs of w
                            try
                                do JavaScript "\(duckJS)" in t
                            end try
                        end repeat
                    end repeat
                end tell
            end if
        end try

        -- Spotify and Music internal volume
        try
            if application "Spotify" is running then
                tell application "Spotify"
                    set sound volume to \(appPercent)
                end tell
            end if
        end try
        try
            if application "Music" is running then
                tell application "Music"
                    set sound volume to \(appPercent)
                end tell
            end if
        end try
        """
        executeAppleScript(script)
    }

    private func runRestoreScript() {
        let sysVol = savedSystemVolume >= 0 ? savedSystemVolume : 100
        let restoreJS = "(function(){document.querySelectorAll('audio,video').forEach(function(e){if(e.dataset.mm!==undefined){e.volume=parseFloat(e.dataset.mm);delete e.dataset.mm;}});})();"

        let script = """
        try
            set volume output volume \(sysVol)
        end try

        try
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            try
                                execute t javascript "\(restoreJS)"
                            end try
                        end repeat
                    end repeat
                end tell
            end if
        end try
        try
            if application "Arc" is running then
                tell application "Arc"
                    repeat with w in windows
                        repeat with t in tabs of w
                            try
                                execute t javascript "\(restoreJS)"
                            end try
                        end repeat
                    end repeat
                end tell
            end if
        end try
        try
            if application "Safari" is running then
                tell application "Safari"
                    repeat with w in windows
                        repeat with t in tabs of w
                            try
                                do JavaScript "\(restoreJS)" in t
                            end try
                        end repeat
                    end repeat
                end tell
            end if
        end try

        try
            if application "Spotify" is running then
                tell application "Spotify"
                    set sound volume to 100
                end tell
            end if
        end try
        try
            if application "Music" is running then
                tell application "Music"
                    set sound volume to 100
                end tell
            end if
        end try
        """
        executeAppleScript(script)
    }

    private func readSystemVolume() -> Int {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: "output volume of (get volume settings)") else { return -1 }
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return -1 }
        let v = Int(result.int32Value)
        return v > 0 ? v : -1  // treat 0 or missing-value (→0) as unsupported
    }

    private func executeAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    // MARK: - Device name (UI only)

    private func getDefaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = kAudioObjectUnknown
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func updateActiveDeviceName() {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else {
            DispatchQueue.main.async { self.activeDeviceName = "None" }
            return
        }
        var name: Unmanaged<CFString>?
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &name)
        if status == noErr, let n = name {
            let str = n.takeUnretainedValue() as String
            DispatchQueue.main.async { self.activeDeviceName = str }
        } else {
            DispatchQueue.main.async { self.activeDeviceName = "Unknown" }
        }
    }

    private func startListeningToDeviceChanges() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(UInt32(kAudioObjectSystemObject), &addr, nil) { _, _ in
            self.updateActiveDeviceName()
        }
    }
}
