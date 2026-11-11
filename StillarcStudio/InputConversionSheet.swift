import SwiftUI

struct InputConversionSheet:View {
    @Bindable var session:EditSession
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Recorded profile",selection:Binding(get:{ session.recipe.input.profile },set:{ profile in session.change { $0.input.profile = profile } })) {
                        ForEach(CameraLogProfile.allCases) { Text($0.title).tag($0) }
                    }.disabled(session.project.isRAW)
                    if let detected = session.project.video?.detectedLog { Text("File metadata identifies \(detected.shortTitle). You can override it if the clip was already converted.").font(.caption).foregroundStyle(.secondary) }
                } footer: { Text(session.project.isRAW ? "RAW photos are already developed to linear color. No Log conversion is needed." : "Choose the profile used to record this file. Log conversion restores normal contrast and color before your edits and creative LUT. Leave already-converted media on Standard.") }
                if session.recipe.input.profile != .standard {
                    Section {
                        HStack { Text("Source exposure");Spacer();Text(session.recipe.input.exposure,format:.number.precision(.fractionLength(2))).monospacedDigit();Text("EV") }
                        Slider(value:$session.recipe.input.exposure,in:-4...4,onEditingChanged:{ $0 ? session.begin() : session.end() })
                        Toggle("Soft highlight roll-off",isOn:Binding(get:{ session.recipe.input.softHighlights },set:{ value in session.change { $0.input.softHighlights = value } }))
                    } footer: { Text("Source exposure changes brightness before converting bright Log highlights to SDR. Soft roll-off gently fits highlights and saturated colors into the display range; it is Studio’s rendering, not Apple’s official Rec.709 LUT.") }
                    Button("Reset input conversion") { session.change { $0.input = InputConversion() } }
                }
            }.navigationTitle("Input conversion").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }.tint(StudioStyle.blue).presentationDetents([.medium,.large])
    }
}
