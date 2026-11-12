import SwiftUI

struct ColorLUTExportSheet:View {
    let recipe:Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var name = "Stillarc Color"
    @State private var dimension = 33
    @State private var busy = false
    @State private var result:URL?
    @State private var error:String?
    @State private var job:Task<URL,Error>?
    var body:some View {
        NavigationStack {
            Form {
                Section { Text("Share the color, keep the original.").font(.headline);Text("Create a display-sRGB .cube LUT for compatible global color adjustments. Apply it after converting your source to standard SDR color. Start with neutral creative edits when applying it, so the grade is not applied twice. This is a color-only approximation, not a complete Studio edit or a Log conversion LUT.").font(.subheadline) }
                Section {
                    TextField("LUT name",text:$name).accessibilityIdentifier("colorLUTName")
                    Picker("Precision",selection:$dimension) { Text("33 · Standard").tag(33);Text("65 · Fine").tag(65) }
                }.disabled(busy || result != nil)
                Section("What is included") { Text("Exposure, white balance, contrast, saturation, vibrance, levels, RGB curves, tone shaping, fade, color mix, wheels, mixer, creative looks and the active LUT. Values outside SDR 0–1 are clipped.").font(.caption) }
                Section("Keep the edit in Studio") {
                    Text("Input conversion, Highlights/Shadows, detail, grain, bloom, vignette, masks, framing, clip settings and HDR cannot travel in this LUT. Export a Studio JSON preset for reusable edit instructions, or use Saved versions for this source’s complete edit including masks and framing.").font(.caption)
                    if !recipe.lutExcludedEdits.isEmpty { Text("Active edits excluded: "+recipe.lutExcludedEdits.joined(separator:", ")).font(.caption).foregroundStyle(.orange) }
                }
                if let error { Section { Text(error).font(.caption).foregroundStyle(.orange) } }
            }.navigationTitle("Export color LUT").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(busy) }
                .safeAreaInset(edge:.bottom) {
                    if let result {
                        ShareLink(item:result) { Label("Share color LUT",systemImage:"square.and.arrow.up") }.buttonStyle(.borderedProminent)
                            .frame(maxWidth:.infinity).padding(14).background(.regularMaterial)
                    } else {
                        Button(busy ? "Creating color LUT…" : "Create color LUT") { create() }.buttonStyle(.borderedProminent).disabled(busy || name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityIdentifier("createColorLUT")
                            .frame(maxWidth:.infinity).padding(14).background(.regularMaterial)
                    }
                }
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .onChange(of:phase) { _,value in if value != .active && busy { job?.cancel() } }
        .onDisappear { job?.cancel();if let result { Task.detached(priority:.utility) { try? FileManager.default.removeItem(at:result.deletingLastPathComponent()) } } }
    }
    private func create() {
        guard !busy else { return };busy = true;error = nil
        let recipe = recipe,dimension = dimension,name = String(name.prefix(100))
        let task = Task.detached(priority:.utility) { try ColorLUTExport.write(ColorLUTExport.make(recipe:recipe,dimension:dimension,name:name)) };job = task
        Task { @MainActor in
            defer { busy = false;job = nil }
            do { result = try await task.value } catch is CancellationError { error = "LUT creation cancelled. Your edit is unchanged." } catch { self.error = error.localizedDescription }
        }
    }
}
