import SwiftUI
import PhotosUI

@main struct StillarcStudioApp: App {
    #if DEBUG
    init() {
        let flags = ProcessInfo.processInfo.arguments.filter { $0.hasPrefix("--verify-") || $0 == "--sustained-preview" }
        if !flags.isEmpty {
            let record:[String:Any] = ["version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","flags":flags,"started":Date().timeIntervalSince1970]
            let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("diagnostic-launch.json")
            if let data = try? JSONSerialization.data(withJSONObject:record) { try? data.write(to:url,options:.atomic) }
        }
    }
    #endif
    @State private var library = StudioLibrary()
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--verify-slider-gestures") { SliderGestureVerificationView() }
                else if ProcessInfo.processInfo.arguments.contains("--verify-video-preview") { VideoPreviewVerification() }
                else { StudioHome(library:library) }
                #else
                StudioHome(library:library)
                #endif
            }.preferredColorScheme(.dark).tint(StudioStyle.blue)
        }
    }
}
enum StudioStyle {
    static let blue = Color(red: 0.25, green: 0.52, blue: 1)
    static let ink = Color(red: 0.025, green: 0.03, blue: 0.04)
    static let panel = Color(red: 0.065, green: 0.075, blue: 0.095)
    static let secondary = Color(red: 0.55, green: 0.6, blue: 0.7)
}
@MainActor struct StudioMark: View {
    var size: CGFloat = 38
    var body: some View {
        ZStack {
            Circle().trim(from: 0.04, to: 0.46).stroke(StudioStyle.blue, style: StrokeStyle(lineWidth: size * 0.07,lineCap: .round)).rotationEffect(.degrees(-90))
            Circle().trim(from: 0.54, to: 0.96).stroke(StudioStyle.blue, style: StrokeStyle(lineWidth: size * 0.07,lineCap: .round)).rotationEffect(.degrees(-90))
            Text("S").font(.system(size: size * 0.65, weight: .medium, design: .serif)).foregroundStyle(.white)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
@MainActor struct StudioHome: View {
    @Bindable var library: StudioLibrary
    @State private var selected: Project?
    @State private var picker: PhotosPickerItem?
    @State private var files = false
    @State private var info = false
    @State private var deletion: Project?
    @State private var demoBusy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 12) {
                        StudioMark()
                        VStack(alignment: .leading, spacing: 1) {
                            Text("STILLARC").font(.system(size: 11,weight: .bold,design: .monospaced)).tracking(3).foregroundStyle(StudioStyle.secondary)
                            Text("Studio").font(.system(size: 27,weight: .semibold))
                        }
                        Spacer()
                        Button { info = true } label: { Image(systemName: "info.circle").font(.title3).frame(width: 44,height: 44).background(.white.opacity(0.06),in: Circle()) }.accessibilityLabel("About Stillarc Studio")
                    }
                    hero
                    HStack {
                        Text("Your workspace").font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(library.projects.count) \(library.projects.count == 1 ? "item" : "items")").font(.caption.monospaced()).foregroundStyle(StudioStyle.secondary)
                    }
                    if library.loading { ProgressView().frame(maxWidth: .infinity) }
                    else if library.projects.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("A space for your point of view.").font(.headline)
                            Text("Open photo or video to start. Your original stays untouched, and every adjustment stays editable.").font(.subheadline).foregroundStyle(StudioStyle.secondary).lineSpacing(3)
                        }.padding(22).frame(maxWidth: .infinity,alignment: .leading).background(StudioStyle.panel,in: RoundedRectangle(cornerRadius: 22))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150),spacing: 14)],spacing: 20) {
                            ForEach(library.projects) { project in
                                Button { selected = project } label: {
                                    VStack(alignment: .leading,spacing: 9) {
                                        ProjectThumbnail(project: project, vault: library.vault)
                                            .aspectRatio(0.9,contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18))
                                        Text(project.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                        Text("\(project.isVideo ? "VIDEO" : (project.isRAW ? "RAW" : "PHOTO")) · \(project.width) × \(project.height)").font(.system(size: 10,design: .monospaced)).foregroundStyle(StudioStyle.secondary)
                                    }.foregroundStyle(.white)
                                }.buttonStyle(.plain).contextMenu {
                                    Button("Delete Studio copy",systemImage: "trash",role: .destructive) { deletion = project }
                                }
                            }
                        }
                    }
                    HStack(spacing: 6) { Image(systemName: "lock.shield"); Text("On your device. In your hands.") }
                        .font(.caption).foregroundStyle(StudioStyle.secondary).frame(maxWidth: .infinity).padding(.vertical,12)
                }.padding(22).frame(maxWidth: 980).frame(maxWidth: .infinity)
            }
            .background(StudioStyle.ink)
            .toolbar(.hidden,for: .navigationBar)
            .safeAreaInset(edge: .bottom) { importBar }
            .task {
                #if DEBUG
                let qa = ProcessInfo.processInfo.arguments.contains("--verify-video-suite") || ProcessInfo.processInfo.arguments.contains("--verify-studio") || ProcessInfo.processInfo.arguments.contains("--verify-tracking-only") || ProcessInfo.processInfo.arguments.contains("--verify-automatic-only")
                let oldIdle = UIApplication.shared.isIdleTimerDisabled
                if qa { UIApplication.shared.isIdleTimerDisabled = true }
                defer { if qa { UIApplication.shared.isIdleTimerDisabled = oldIdle } }
                #endif
                await library.load()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--verify-automatic-only") {
                    let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("automatic-verification.json")
                    do {
                        let report = try await Task.detached { ["math":try AutomaticSelectionVerification.math(),"inference":try await AutomaticSelectionVerification.inference(),"passed":true] as [String:Any] }.value
                        try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:url,options:.atomic)
                    } catch { try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic) }
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-tracking-only") {
                    let reportURL = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("tracking-verification.json")
                    do { let report = try await Task.detached { try await TrackingVerification.video() }.value;try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:reportURL,options:.atomic) }
                    catch { try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:reportURL,options:.atomic) }
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-video-suite") { await VideoVerification.writeReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-studio") { await StudioVerification.run(library: library) }
                if ProcessInfo.processInfo.arguments.contains("--tracking-demo"),let url = try? await TrackingVerification.fixture() {
                    selected = await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent())
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-trim-ui") || ProcessInfo.processInfo.arguments.contains("--verify-versions-ui") || ProcessInfo.processInfo.arguments.contains("--verify-transfer-ui") || ProcessInfo.processInfo.arguments.contains("--verify-mask-ui") || ProcessInfo.processInfo.arguments.contains("--verify-brush-ui") {
                    if let project = library.projects.first(where: { $0.isVideo }) { selected = project }
                    else if let url = try? await VideoFixtures.make(profile:.standard,frames:90) { selected = await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
                }
                if ProcessInfo.processInfo.arguments.contains("--video-demo"),let url = try? await VideoFixtures.make(profile:.standard,frames:90) { selected = await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
                if ProcessInfo.processInfo.arguments.contains("--demo-editor"), let project = await addDemo() { selected = project }
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in Task { await ThumbnailCache.shared.clear() } }
            .onChange(of: picker) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let transfer = try await item.loadTransferable(type: PhotoTransfer.self) else { throw StudioError.unreadable }
                        selected = await library.add(transfer.url)
                        await Task.detached(priority:.utility) { try? FileManager.default.removeItem(at:transfer.url) }.value
                    } catch { library.error = error.localizedDescription }
                    picker = nil
                }
            }
            .fileImporter(isPresented: $files, allowedContentTypes:[.image,.rawImage,.movie,.video]) { result in
                switch result {
                case .success(let url): Task { selected = await library.add(url) }
                case .failure(let error): library.error = error.localizedDescription
                }
            }
            .fullScreenCover(item: $selected) { project in PhotoEditor(project: project, library: library) }
            .sheet(isPresented: $info) { StudioAbout() }
            .alert("Unable to complete",isPresented: Binding(get: { library.error != nil },set: { if !$0 { library.error = nil } })) { Button("OK") { library.error = nil } } message: { Text(library.error ?? "") }
            .confirmationDialog("Delete this Studio project?",isPresented: Binding(get: { deletion != nil },set: { if !$0 { deletion = nil } }),titleVisibility: .visible) {
                Button("Delete Studio copy",role: .destructive) { if let deletion { Task { await library.remove(deletion) } }; deletion = nil }
            } message: { Text("Your original in Photos or Files will remain. The imported Studio copy and its adjustments will be removed.") }
        }
    }
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Image("Hero").resizable().scaledToFill().frame(width: geometry.size.width,height: geometry.size.height).clipped()
            }
            LinearGradient(colors: [.clear,.black.opacity(0.5),.black.opacity(0.95)],startPoint: .top,endPoint: .bottom)
            VStack(alignment: .leading,spacing: 12) {
                Text("YOUR LIGHT. YOUR COLOR.").font(.system(size: 10,weight: .bold,design: .monospaced)).tracking(2).foregroundStyle(Color.white.opacity(0.8))
                Text("Make it\nyour own.").font(.system(size: 42,weight: .semibold,design: .serif)).tracking(-1)
                Button {
                    Task { demoBusy = true; selected = await addDemo(); demoBusy = false }
                } label: {
                    HStack(spacing: 8) { if demoBusy { ProgressView() } else { Image(systemName: "slider.horizontal.3") }; Text("Explore the editor"); Image(systemName: "arrow.up.right") }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal,16).padding(.vertical,12).background(.ultraThinMaterial,in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.16)))
                }.disabled(demoBusy || library.importing).buttonStyle(.plain)
                Text("Illustrative sample · not a camera capture").font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
            }.padding(24)
        }.frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.09)))
    }
    private var importBar: some View {
        let isImporting = library.importing
        return HStack(spacing: 12) {
            PhotosPicker(selection: $picker,matching:.any(of:[.images,.videos]),preferredItemEncoding: .current) {
                HStack(spacing: 9) { Image(systemName: "plus"); Text(isImporting ? "Opening media…" : "Open photo or video").fontWeight(.semibold) }.frame(maxWidth: .infinity).frame(height: 54).background(StudioStyle.blue,in: Capsule()).foregroundStyle(.white)
            }.disabled(library.importing)
            Button { files = true } label: { Image(systemName: "folder").font(.title3).frame(width: 54,height: 54).background(.white.opacity(0.08),in: Circle()) }.disabled(library.importing).accessibilityLabel("Import photo or video from Files")
        }.padding(.horizontal,22).padding(.vertical,14).background(.ultraThinMaterial)
    }
    private func addDemo() async -> Project? {
        if let existing = library.projects.first(where: { $0.name == "Studio sample" }) { return existing }
        guard let url = Bundle.main.url(forResource: "Sample",withExtension: "jpg"), var project = await library.add(url) else { return nil }
        project.name = "Studio sample"; await library.save(project); return project
    }
}
@MainActor struct ProjectThumbnail: View {
    let project: Project
    let vault: ProjectVault
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                StudioStyle.panel
                if let image { Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width,height: geometry.size.height).clipped() }
                else { Image(systemName: "photo").foregroundStyle(StudioStyle.secondary) }
            }
        }.task(id: project.modified) {
            let url = await vault.source(project)
            image = await ThumbnailCache.shared.image(url: url, project: project)
        }
    }
}
@MainActor struct StudioAbout: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading,spacing: 24) {
                    StudioMark(size: 70)
                    Text("A little room\nfor a bigger vision.").font(.largeTitle.weight(.semibold))
                    Text("Stillarc Studio · Dehaze · Refined preview motion · 0.19.0").font(.caption.monospaced()).foregroundStyle(StudioStyle.blue)
                    Text("Develop light, color and texture with reversible adjustments. Import from Photos or Files, save looks and export JPEG/PNG photographs or trimmed HEVC video with audio in SDR or 10-bit HLG HDR.")
                    Text("Dehaze reduces a washed-out veil or adds soft haze. Texture brings out fine surfaces or softens them; Clarity changes broader definition. The preview stays large, and Expand preview hides adjustments. Tap video to show playback controls. Use Scopes to inspect brightness and color. Drag crop corners to resize and drag inside to reposition. Fixed ratios stay locked; Free lets each edge change. Flips and perspective help refine your composition; every change stays reversible.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Drag the split divider to compare original and edit. Save complete versions under Looks to try different grades and return to a favorite.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Copy selected adjustments under Looks, then paste them onto another photo or clip. Its framing, camera input and trim stay intact; undo reverses the paste.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Use Masks to brighten a face or darken part of a sky. Linear and radial shapes have soft edges, inversion and strength; the red guide is only a preview. Masks stay with this source; Radial, Brush and Subject masks can use position tracking.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Select foreground subjects or sky with one on-device analysis, then refine the saved selection. Video uses the first kept frame; subjects can use position tracking afterward. Track radial or painted masks through a video clip using a chosen target region. Analysis runs separately; saved motion drives playback and export. Tracks position only, with no deformation or scale/rotation tracking. Double-tap any slider to reset its default. Combine a mask with the previous selection using Intersect, Add or Subtract. Use Color masks to change similar colors or Luminance masks to adjust dark, middle or bright areas. Soft transitions blend the selection; the guide shows what is selected. Paint a brush mask to adjust a specific area. Eraser removes it, View restores playback controls, and undo removes a whole stroke. Brush size and softness apply to new strokes; full-resolution exports keep the detailed mask.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Label("Originals stay untouched",systemImage: "lock.shield")
                    Label("No account or upload required",systemImage: "wifi.slash")
                    Label("Preview draws only when needed",systemImage: "leaf")
                    DisclosureGroup("Sky model acknowledgements") {
                        Text((Bundle.main.url(forResource:"ModelNotices",withExtension:"txt").flatMap { try? String(contentsOf:$0,encoding:.utf8) }) ?? "Sky segmentation model: xiongzhu666; Core ML conversion: twistlabs/fotometis-sky. MIT license.").font(.caption).textSelection(.enabled)
                    }.font(.subheadline)
                    Text("Photos export as SDR JPEG/PNG. Video supports SDR or 10-bit HLG HDR, with extended-range previews on compatible screens. Apple Log/Log 2 and HLG/PQ video inputs are supported. RAW photo support depends on Apple's decoder. Video RAW, changing-pose video segmentation, healing and a multi-clip timeline remain planned.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("The bundled sample is an AI-generated illustrative scene from the Stillarc Camera marketing library.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(26)
            }.background(StudioStyle.ink).navigationTitle("Stillarc Studio").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }.tint(StudioStyle.blue)
    }
}
