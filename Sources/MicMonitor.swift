import Foundation
import CoreAudio
import Combine

class MicMonitor: ObservableObject {
    static let shared = MicMonitor()
    
    @Published var isSpeaking = false
    
    // Silence timer prevents immediate unducking if mic temporarily stops
    private let silenceDuration: TimeInterval = 0.5 
    private var silenceTimer: Timer?
    
    private var defaultInputDeviceID: AudioDeviceID = kAudioObjectUnknown
    
    private let propertyListener: AudioObjectPropertyListenerProc = { objectID, numberAddresses, inAddresses, clientData in
        DispatchQueue.main.async {
            MicMonitor.shared.handleMicStatusChange()
        }
        return noErr
    }
    
    private let deviceChangeListener: AudioObjectPropertyListenerProc = { objectID, numberAddresses, inAddresses, clientData in
        DispatchQueue.main.async {
            MicMonitor.shared.handleDefaultInputDeviceChange()
        }
        return noErr
    }
    
    func startMonitoring() {
        // Listen to default input device changes
        var deviceChangeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &deviceChangeAddress, deviceChangeListener, nil)
        
        handleDefaultInputDeviceChange()
    }
    
    func stopMonitoring() {
        var deviceChangeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &deviceChangeAddress, deviceChangeListener, nil)
        
        removeMicStatusListener()
        setSpeaking(false)
    }
    
    func handleDefaultInputDeviceChange() {
        removeMicStatusListener()
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultInputDeviceID
        )
        
        if status == noErr && defaultInputDeviceID != kAudioObjectUnknown {
            addMicStatusListener()
            handleMicStatusChange()
        }
    }
    
    private func addMicStatusListener() {
        var isRunningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(defaultInputDeviceID, &isRunningAddress, propertyListener, nil)
    }
    
    private func removeMicStatusListener() {
        if defaultInputDeviceID != kAudioObjectUnknown {
            var isRunningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListener(defaultInputDeviceID, &isRunningAddress, propertyListener, nil)
        }
    }
    
    func handleMicStatusChange() {
        guard defaultInputDeviceID != kAudioObjectUnknown else { return }
        
        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var isRunningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &isRunningAddress,
            0,
            nil,
            &dataSize,
            &isRunning
        )
        
        if status == noErr {
            let active = isRunning != 0
            if active {
                setSpeaking(true)
            } else {
                startSilenceTimer()
            }
        }
    }
    
    private func setSpeaking(_ speaking: Bool) {
        if speaking {
            silenceTimer?.invalidate()
            silenceTimer = nil
            if !isSpeaking {
                isSpeaking = true
                AudioDucker.shared.startDucking()
            }
        } else {
            if isSpeaking {
                isSpeaking = false
                AudioDucker.shared.stopDucking()
            }
        }
    }
    
    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDuration, repeats: false) { [weak self] _ in
            self?.setSpeaking(false)
        }
    }
}
