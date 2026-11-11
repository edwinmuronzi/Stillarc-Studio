import SwiftUI
import Photos
import UniformTypeIdentifiers

@MainActor struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: EditSession
    @State private var format: ExportFormat = .jpeg
    @State private var result: ExportResult?
    @State private var busy = false
    @State private var message: String?
    @State private var error: String?
    @State private var saving = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading,spacing: 26) {
                    Image(systemName: "square.and.arrow.up.circle").font(.system(size: 46,weight: .light)).foregroundStyle(StudioStyle.blue)
                    Text("Ready for\nthe world.").font(.system(size: 36,weight: .semibold,design: .serif))
                    Text("A finished copy. Your original stays yours.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Picker("File format",selection: $format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).disabled(busy || result != nil)
                    VStack(alignment: .leading,spacing: 14) {
                        exportDetail("Resolution",value: "Full original · crop applied")
                        exportDetail("Color",value: "sRGB · SDR")
                        exportDetail("Quality",value: format == .jpeg ? "96% JPEG" : "Lossless PNG · 8-bit")
                        exportDetail("Privacy",value: "Location metadata omitted")
                    }.padding(20).background(StudioStyle.panel,in: RoundedRectangle(cornerRadius: 20))
                    if let result {
                        Label("\(result.width) × \(result.height) · Ready",systemImage: "checkmark.circle.fill").foregroundStyle(StudioStyle.blue).font(.subheadline)
                        ShareLink(item: result.url) { Label("Share or save to Files",systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(17).background(StudioStyle.blue,in: Capsule()).foregroundStyle(.white) }
                        Button { Task { await saveToPhotos(result.url) } } label: { HStack { if saving { ProgressView() }; Label("Save to Photos",systemImage: "photo.badge.arrow.down") }.frame(maxWidth: .infinity).padding(17).background(.white.opacity(0.07),in: Capsule()) }.disabled(saving)
                        Button("Change export format") { self.result = nil; message = nil }.font(.subheadline).frame(maxWidth: .infinity)
                    } else {
                        Button { Task { await render() } } label: {
                            HStack { if busy { ProgressView().tint(.white) }; Text(busy ? "Developing full-resolution photo…" : "Create export").fontWeight(.semibold) }.font(.subheadline).frame(maxWidth: .infinity).padding(17).background(StudioStyle.blue,in: Capsule()).foregroundStyle(.white)
                        }.disabled(busy)
                    }
                    if let message { Label(message,systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(StudioStyle.blue) }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.orange) }
                    Text("The same adjustments are applied to the full-resolution source. Large RAW files can take longer to develop; you can continue editing after closing this sheet.").font(.caption).foregroundStyle(StudioStyle.secondary).lineSpacing(3)
                }.padding(26)
            }.background(StudioStyle.ink).navigationTitle("Export photo").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(saving) }
                .interactiveDismissDisabled(saving)
        }.tint(StudioStyle.blue)
    }
    private func exportDetail(_ name: String,value: String) -> some View { HStack { Text(name).foregroundStyle(StudioStyle.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.caption) }
    private func render() async {
        guard let source = session.sourceURL else { return }
        busy = true; error = nil
        let recipe = session.recipe, format = format
        defer { busy = false }
        do { result = try await Task.detached(priority: .userInitiated) { try ImageEngine.export(source: source,recipe: recipe,format: format) }.value }
        catch { self.error = error.localizedDescription }
    }
    private func saveToPhotos(_ url: URL) async {
        saving = true; error = nil
        defer { saving = false }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else { error = "Allow Stillarc Studio to add photos in Settings, or use Share to save to Files."; return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) }
            message = "Saved to Photos."
        } catch { self.error = error.localizedDescription }
    }
}
@MainActor struct PresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: EditSession
    @Bindable var library: StudioLibrary
    @State private var naming = false
    @State private var name = ""
    @State private var importing = false
    @State private var importingLUT = false
    @State private var loadingLUT = false
    @State private var shareURL: URL?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { naming = true } label: { Label("Save current adjustments",systemImage: "plus.circle") }
                    Button { importingLUT = true } label: { Label("Import .cube LUT",systemImage:"cube.transparent") }.disabled(loadingLUT)
                    if loadingLUT { ProgressView("Preparing LUT…") }
                    Button { importing = true } label: { Label("Import Studio preset",systemImage: "square.and.arrow.down") }
                } footer: { Text("Presets save light, color, film and the LUT itself. Crop and rotation stay with the photograph. Import a display-sRGB LUT, then adjust its strength under Film.") }
                Section("Your presets") {
                    if library.looks.isEmpty { Text("Your signature looks will live here.").foregroundStyle(StudioStyle.secondary) }
                    ForEach(library.looks) { look in
                        HStack {
                            Button {
                                session.change { recipe in let framing = recipe; recipe = look.recipe; recipe.copyFraming(from: framing) }
                                dismiss()
                            } label: { Label(look.name,systemImage: "camera.filters").foregroundStyle(.white) }
                            Spacer()
                            Menu {
                                Button("Export preset",systemImage: "square.and.arrow.up") { Task { await exportLook(look) } }
                                Button("Delete preset",systemImage: "trash",role: .destructive) { Task { await library.removeLook(look) } }
                            } label: { Image(systemName: "ellipsis.circle").frame(width: 44,height: 44) }.accessibilityLabel("Manage \(look.name)")
                        }
                    }
                }
                if let shareURL {
                    Section { ShareLink(item: shareURL) { Label("Share exported preset",systemImage: "square.and.arrow.up") } }
                }
                if let error { Section { Text(error).foregroundStyle(.orange) } }
            }.scrollContentBackground(.hidden).background(StudioStyle.ink).navigationTitle("Your looks").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() }.disabled(loadingLUT) }
                .interactiveDismissDisabled(loadingLUT)
                .alert("Save preset",isPresented: $naming) {
                    TextField("Preset name",text: $name)
                    Button("Cancel",role: .cancel) {}
                    Button("Save") {
                        let recipe = session.recipe.colorPreset
                        Task { if await library.saveLook(name:name,recipe:recipe) { name = "" } else { error = library.error } }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } message: { Text("Give this combination of adjustments a name.") }
                .fileImporter(isPresented:$importingLUT,allowedContentTypes:[UTType(filenameExtension:"cube") ?? .data,.plainText]) { result in
                    switch result {
                    case .success(let url): Task { await importLUT(url) }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
                .fileImporter(isPresented: $importing,allowedContentTypes: [.json]) { result in
                    switch result {
                    case .success(let url): Task { await importLook(url) }
                    case .failure(let error): self.error = error.localizedDescription
                    }
                }
        }.tint(StudioStyle.blue)
    }
    private func importLUT(_ url: URL) async {
        loadingLUT = true; error = nil
        defer { loadingLUT = false }
        do {
            let asset = try await Task.detached(priority:.userInitiated) { try LUTAsset.read(url) }.value
            var preset = Recipe(); preset.lut = asset
            guard await library.saveLook(name:asset.name.isEmpty ? "Imported LUT" : asset.name,recipe:preset) else { error = library.error; return }
            session.change { $0.lut = asset; $0.lutAmount = 1 }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
    private func exportLook(_ look: SavedLook) async {
        do {
            let url = try await Task.detached(priority: .utility) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Stillarc-Preset-\(look.id.uuidString.prefix(8)).json")
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
                try encoder.encode(PresetDocument(name: look.name,recipe: look.recipe)).write(to: url,options: .atomic)
                return url
            }.value
            shareURL = url
        } catch { self.error = error.localizedDescription }
    }
    private func importLook(_ url: URL) async {
        do {
            let preset = try await Task.detached(priority: .userInitiated) {
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.fileSizeKey]); guard (values.fileSize ?? 0) <= 8_000_000 else { throw StudioError.unsupportedPreset }
                let preset = try JSONDecoder().decode(PresetDocument.self,from: Data(contentsOf: url))
                guard (1...2).contains(preset.schema) else { throw StudioError.unsupportedPreset }
                return preset
            }.value
            if !(await library.saveLook(name:preset.name,recipe:preset.recipe.validated())) { error = library.error }
        } catch { self.error = error.localizedDescription }
    }
}
