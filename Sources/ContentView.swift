import SwiftUI

struct ContentView: View {
    @StateObject private var audioDucker = AudioDucker.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var micMonitor = MicMonitor.shared
    
    @AppStorage("duckingPercentage") private var duckingPercentage: Double = 0.5
    
    var body: some View {
        VStack(spacing: 12) {
            Text("MinMic Status")
                .font(.headline)
            
            Text(audioDucker.isDucking ? "Active - Audio Ducked" : "Inactive - Normal Audio")
                .foregroundColor(audioDucker.isDucking ? .green : .secondary)
                .font(.subheadline)
            
            if micMonitor.isSpeaking {
                Text("🎙️ Voice Detected")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("🎙️ Listening for Voice...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Ducking Level (0% to 100% reduction)")
                    .font(.caption)
                HStack {
                    Text("0%")
                        .font(.caption2)
                    Slider(value: $duckingPercentage, in: 0.1...1.0)
                        .onChange(of: duckingPercentage) { newValue in
                            audioDucker.updateDuckingPercentage(newValue)
                        }
                    Text("100%")
                        .font(.caption2)
                }
                Text("Current: \(Int(duckingPercentage * 100))%")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal)
            
            Divider()
            
            Text("Active Device: \(audioDucker.activeDeviceName)")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Divider()
            
            Button(action: {
                if let url = URL(string: "https://paypal.me/yourusername") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label("Donate to PayPal", systemImage: "heart.fill")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Button("Quit MinMic") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 250)
        .onAppear {
            audioDucker.updateDuckingPercentage(duckingPercentage)
        }
    }
}
