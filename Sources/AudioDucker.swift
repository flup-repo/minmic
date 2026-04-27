import Foundation
import CoreAudio
import AudioToolbox
import Combine

class AudioDucker: ObservableObject {
    static let shared = AudioDucker()
    
    @Published var isDucking: Bool = false
    @Published var activeDeviceName: String = "Discovering..."
    
    private var duckingPercentage: Double = 0.5
    private var originalVolumes: [UInt32: Float32] = [:]
    private var defaultOutputDeviceID: AudioDeviceID = kAudioObjectUnknown
    
    init() {
        updateActiveDeviceName()
        // Listen to default output device changes
        startListeningToDeviceChanges()
    }
    
    func updateDuckingPercentage(_ percentage: Double) {
        self.duckingPercentage = percentage
        if isDucking {
            // Re-apply if already ducking
            stopDucking()
            startDucking()
        }
    }
    
    private var fadeWorkItem: DispatchWorkItem?
    
    func startDucking() {
        if isDucking { return }
        isDucking = true
        
        let deviceID = getDefaultOutputDeviceID()
        defaultOutputDeviceID = deviceID
        updateActiveDeviceName()
        
        guard deviceID != kAudioObjectUnknown else { return }
        
        originalVolumes.removeAll()

        let vol = getMasterVolume(for: deviceID)
        originalVolumes[0] = vol
        let targetVol = vol * Float32(1.0 - duckingPercentage)
        let targets: [(channel: UInt32, startVol: Float32, targetVol: Float32)] = [(0, vol, targetVol)]

        fadeVolumes(deviceID: deviceID, targets: targets, duration: 0.15)
        runMediaAppleScript(duck: true)
    }
    
    func stopDucking() {
        if !isDucking { return }
        isDucking = false
        
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return }
        
        var targets: [(channel: UInt32, startVol: Float32, targetVol: Float32)] = []
        for (channel, vol) in originalVolumes {
            let currentVol = getMasterVolume(for: defaultOutputDeviceID)
            targets.append((channel, currentVol, vol))
        }
        
        fadeVolumes(deviceID: defaultOutputDeviceID, targets: targets, duration: 0.15)
        originalVolumes.removeAll()
        runMediaAppleScript(duck: false)
    }
    
    private func fadeVolumes(deviceID: AudioDeviceID, targets: [(channel: UInt32, startVol: Float32, targetVol: Float32)], duration: TimeInterval) {
        fadeWorkItem?.cancel()
        
        let steps = 15
        let stepDuration = duration / Double(steps)
        
        let item = DispatchWorkItem { [weak self] in
            for step in 1...steps {
                guard let self = self, !Thread.current.isCancelled else { return }
                let progress = Float32(step) / Float32(steps)
                
                for target in targets {
                    let newVol = target.startVol + (target.targetVol - target.startVol) * progress
                    self.setVolume(for: deviceID, channel: target.channel, volume: newVol)
                }
                
                Thread.sleep(forTimeInterval: stepDuration)
            }
        }
        
        fadeWorkItem = item
        DispatchQueue.global(qos: .userInteractive).async(execute: item)
    }
    
    // MARK: - Core Audio Helpers

    private func masterVolumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func getMasterVolume(for deviceID: AudioDeviceID) -> Float32 {
        var volume: Float32 = 1.0
        var addr = masterVolumeAddress()
        var size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume)
        return volume
    }

    private func setVolume(for deviceID: AudioDeviceID, channel: UInt32, volume: Float32) {
        var vol = max(0.0, min(1.0, volume))
        var addr = masterVolumeAddress()
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &vol)
    }

    private func getDefaultOutputDeviceID() -> AudioDeviceID {
        var defaultOutputDeviceID = kAudioObjectUnknown
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            UInt32(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )
        
        if status != noErr {
            print("Failed to get default output device ID")
            return kAudioObjectUnknown
        }
        return defaultOutputDeviceID
    }
    
    private func updateActiveDeviceName() {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else {
            DispatchQueue.main.async { self.activeDeviceName = "None" }
            return
        }
        
        var name: Unmanaged<CFString>?
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &name)
        
        if status == noErr, let unmanagedName = name {
            let nameStr = unmanagedName.takeUnretainedValue() as String
            DispatchQueue.main.async { self.activeDeviceName = nameStr }
        } else {
            DispatchQueue.main.async { self.activeDeviceName = "Unknown" }
        }
    }
    
    private func startListeningToDeviceChanges() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(UInt32(kAudioObjectSystemObject), &address, nil) { _, _ in
            self.updateActiveDeviceName()
        }
    }
    
    // MARK: - Media Player Override (AppleScript)
    private func runMediaAppleScript(duck: Bool) {
        // Fast script using AppleScript to mute Apple Music and Spotify
        let scriptStr: String
        let duckPercentInt = Int((1.0 - duckingPercentage) * 100)
        if duck {
            scriptStr = """
            try
                if application "Music" is running then
                    tell application "Music"
                        set sound volume to \(duckPercentInt)
                    end tell
                end if
            end try
            try
                if application "Spotify" is running then
                    tell application "Spotify"
                        set sound volume to \(duckPercentInt)
                    end tell
                end if
            end try
            """
        } else {
            scriptStr = """
            try
                if application "Music" is running then
                    tell application "Music"
                        set sound volume to 100
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
            """
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptStr) {
                scriptObject.executeAndReturnError(&error)
            }
        }
    }
}
