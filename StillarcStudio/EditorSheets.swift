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
    @State private var videoProgress = 0.0
    @State private var tenBitVideo = true
    @State private var coolingVideo = false
    @State private var exportTask:Task<ExportResult,Error>?
    @Environment(\.scenePhase) private var phase
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading,spacing: 26) {
                    Image(systemName: "square.and.arrow.up.circle").font(.system(size: 46,weight: .light)).foregroundStyle(StudioStyle.blue)
                    Text("Ready for\nthe world.").font(.system(size: 36,weight: .semibold,design: .serif))
                    Text("A finished copy. Your original stays yours.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    if !session.project.isVideo { Picker("File format",selection: $format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).disabled(busy || result != nil) }
                    if session.project.isVideo { Toggle("HDR video · HLG",isOn:Binding(get:{ session.recipe.video.hdr },set:{ value in session.change { $0.video.hdr = value } })).disabled(busy || result != nil);Text("HDR keeps brighter highlights on supported screens. SDR is the safest choice for universal sharing. HDR uses 10-bit HEVC; SDR looks/LUTs can change highlight detail.").font(.caption).foregroundStyle(StudioStyle.secondary) }
                    if session.project.isVideo { Picker("Video depth",selection:$tenBitVideo) { Text("10-bit HEVC").tag(true);Text("8-bit HEVC").tag(false) }.pickerStyle(.segmented).disabled(busy || result != nil || session.recipe.video.hdr) }
                    VStack(alignment: .leading,spacing: 14) {
                        exportDetail("Resolution",value: "Full original · crop applied")
                        exportDetail("Color",value:session.project.isVideo ? (session.recipe.video.hdr ? "Rec.2020 · HLG HDR" : "sRGB · SDR") : "sRGB · SDR")
                        exportDetail("Quality",value:session.project.isVideo ? "HEVC · \((tenBitVideo || session.recipe.video.hdr) ? 10 : 8)-bit · source frame timing" : (format == .jpeg ? "96% JPEG" : "Lossless PNG · 8-bit"))
                        if let video = session.project.video { let r = session.recipe.video.range(duration:video.duration);exportDetail("Duration",value:String(format:"%.2f seconds",r.upperBound-r.lowerBound)) }
                        if session.project.isVideo { exportDetail("Audio",value:"Original tracks preserved") }
                        exportDetail("Privacy",value: "Location metadata omitted")
                    }.padding(20).background(StudioStyle.panel,in: RoundedRectangle(cornerRadius: 20))
                    if let result {
                        Label("\(result.width) × \(result.height) · Ready",systemImage: "checkmark.circle.fill").foregroundStyle(StudioStyle.blue).font(.subheadline)
                        ShareLink(item: result.url) { Label("Share or save to Files",systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(17).background(StudioStyle.blue,in: Capsule()).foregroundStyle(.white) }
                        Button { Task { await saveToPhotos(result.url) } } label: { HStack { if saving { ProgressView() }; Label("Save to Photos",systemImage: "photo.badge.arrow.down") }.frame(maxWidth: .infinity).padding(17).background(.white.opacity(0.07),in: Capsule()) }.disabled(saving)
                        Button("Change export format") { discardExport(); message = nil }.font(.subheadline).frame(maxWidth: .infinity)
                    } else {
                        Button { Task { await render() } } label: {
                            HStack { if busy { ProgressView().tint(.white) }; Text(busy ? (session.project.isVideo ? "Exporting video…" : "Developing full-resolution photo…") : "Create export").fontWeight(.semibold) }.font(.subheadline).frame(maxWidth: .infinity).padding(17).background(StudioStyle.blue,in: Capsule()).foregroundStyle(.white)
                        }.disabled(busy)
                    }
                    if busy && session.project.isVideo { ProgressView(value:videoProgress);if coolingVideo { Text("Paused to cool your iPhone. Export resumes when thermal state improves.").font(.caption).foregroundStyle(StudioStyle.secondary) };Button("Cancel export",role:.cancel) { exportTask?.cancel() } }
                    if let message { Label(message,systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(StudioStyle.blue) }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.orange) }
                    Text("The same adjustments are applied to the full-resolution source. Large RAW files can take longer to develop; you can continue editing after closing this sheet.").font(.caption).foregroundStyle(StudioStyle.secondary).lineSpacing(3)
                }.padding(26)
            }.background(StudioStyle.ink).navigationTitle(session.project.isVideo ? "Export video" : "Export photo").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(saving || busy) }
                .interactiveDismissDisabled(saving || busy)
        }.tint(StudioStyle.blue)
        .onDisappear { exportTask?.cancel();discardExport() }
        .onChange(of:phase) { _,value in if value != .active { exportTask?.cancel() } }
        .onChange(of:session.recipe.video.hdr) { _,value in if value { tenBitVideo = true } }
    }
    private func discardExport() {
        guard let url = result?.url else { return };result = nil
        Task.detached(priority:.utility) { try? FileManager.default.removeItem(at:url) }
    }
    private func exportDetail(_ name: String,value: String) -> some View { HStack { Text(name).foregroundStyle(StudioStyle.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.caption) }
    private func render() async {
        guard let source = session.sourceURL else { return }
        busy = true;error = nil;videoProgress = 0
        let recipe = session.recipe,format = format,video = session.project.video,tenBit = tenBitVideo
        defer { busy = false;exportTask = nil }
        let task = Task.detached(priority:.utility) {
            if let video { return try await VideoEngine.export(source:source,descriptor:video,recipe:recipe,tenBit:tenBit,progress:{ value in await MainActor.run { videoProgress = value } },cooling:{ value in await MainActor.run { coolingVideo = value } }) }
            return try ImageEngine.export(source:source,recipe:recipe,format:format)
        }
        exportTask = task
        do { result = try await task.value }
        catch is CancellationError { error = "Export cancelled. Your source and edits are safe." }
        catch { self.error = error.localizedDescription }
    }
    private func saveToPhotos(_ url: URL) async {
        saving = true; error = nil
        defer { saving = false }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else { error = "Allow Stillarc Studio to add photos in Settings, or use Share to save to Files."; return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if url.pathExtension.lowercased() == "mov" { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:url) }
                else { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:url) }
            }
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
                } footer: { Text("Presets save light, color, film and the LUT itself. Input conversion, crop and rotation stay with the source. Import a display-sRGB LUT, then adjust its strength under Film.") }
                Section("Your presets") {
                    if library.looks.isEmpty { Text("Your signature looks will live here.").foregroundStyle(StudioStyle.secondary) }
                    ForEach(library.looks) { look in
                        HStack {
                            Button {
                                session.change { recipe in let framing = recipe; recipe = look.recipe; recipe.copyFraming(from: framing); recipe.input = framing.input;recipe.video = framing.video;recipe.masks = framing.masks }
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
