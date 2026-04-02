import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMeasurement = Self("toggleMeasurement")
}

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle Measurement:", name: .toggleMeasurement)
        }
        .padding(20)
        .frame(width: 300)
    }
}
