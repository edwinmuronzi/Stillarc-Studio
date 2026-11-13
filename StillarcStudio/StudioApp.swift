import SwiftUI
import PhotosUI
import CoreImage

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
        Image("StudioBrand").resizable().scaledToFit()
            .frame(width:size,height:size)
            .clipShape(RoundedRectangle(cornerRadius:size*0.21,style:.continuous))
            .accessibilityHidden(true)
    }
}
@MainActor struct StudioHome: View {
    @Bindable var library: StudioLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: Project?
    @State private var editingPool:EditingPool?
    @AppStorage(EditingPool.storageKey) private var savedPoolData=Data()
    @State private var picker:[PhotosPickerItem] = []
    @State private var importingBatch = false
    @State private var importStatus:String?
    @State private var importTask:Task<Void,Never>?
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var batchExport = false
    @State private var batchPaste = false
    @State private var copyProject:Project?
    @State private var pasteProject:Project?
    @State private var revertProject:Project?
    @State private var reverting = false
    @State private var queueSheet=false
    @State private var archives=false
    @State private var archiveIDs=Set<UUID>()
    @State private var recovery = false
    @State private var emptyBinRequested=false
    @State private var files = false
    @State private var originalMedia:Project?
    @State private var lookLibrary=false
    @State private var info = false
    @State private var deletion: Project?
    @State private var deleteIDs = Set<UUID>()
    @State private var confirmBulkDelete = false
    @State private var deletingProjects = false
    @State private var favoritingProjects = false
    @State private var demoBusy = false
    @State private var workspaceSearch = ""
    @FocusState private var searchFocused:Bool
    @AppStorage("studio.library.filter") private var filterRaw = LibraryFilter.all.rawValue
    @AppStorage("studio.library.sort") private var sortRaw = LibrarySort.edited.rawValue
    private var filter:LibraryFilter { LibraryFilter(rawValue:filterRaw) ?? .all }
    private var sort:LibrarySort { LibrarySort(rawValue:sortRaw) ?? .edited }
    private var visibleProjects:[Project] { LibraryQuery.projects(library.projects,query:workspaceSearch,filter:filter,sort:sort) }
    var body: some View {
        let items = visibleProjects
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
                        Button {lookLibrary=true} label:{Image(systemName:"camera.filters").font(.title3).frame(width:44,height:44).background(.white.opacity(0.06),in:Circle())}.accessibilityLabel("Look library").accessibilityIdentifier("homeLookLibrary")
                        Button { info = true } label: { Image(systemName: "info.circle").font(.title3).frame(width: 44,height: 44).background(.white.opacity(0.06),in: Circle()) }.accessibilityLabel("About Stillarc Studio")
                    }
                    hero
                    HStack {
                        Text("Your workspace").font(.title3.weight(.semibold))
                        Button(selecting ? "Done" : "Select") { searchFocused = false;selecting.toggle();if !selecting { selection = [] } }.font(.caption).disabled(importingBatch || library.importing)
                        Spacer()
                        Text("\(items.count) of \(library.projects.count)").font(.caption.monospaced()).foregroundStyle(StudioStyle.secondary)
                    }
                    workspaceControls
                    if !library.exportQueue.jobs.isEmpty {Button("Export queue (\(library.exportQueue.jobs.count))",systemImage:"list.bullet.rectangle"){searchFocused=false;queueSheet=true}.font(.caption).buttonStyle(.bordered).accessibilityIdentifier("homeExportQueue")}
                    if !selecting,let state=try? JSONDecoder().decode(EditingPoolState.self,from:savedPoolData),state.available(library.projects) != nil {
                        Button("Resume editing pool",systemImage:"rectangle.stack") {if let available=state.available(library.projects) {searchFocused=false;editingPool=EditingPool(available)}}.font(.caption).buttonStyle(.bordered)
                    }
                    if let status = importStatus {
                        HStack { if importingBatch { ProgressView() };Text(status).font(.caption);Spacer();if importingBatch { Button("Cancel remaining") { importTask?.cancel() }.font(.caption) } }
                    }
                    if let notice = library.recoveryMessage { HStack(alignment:.top) { Text(notice).font(.caption).foregroundStyle(StudioStyle.secondary);Spacer();Button { library.recoveryMessage = nil } label: { Image(systemName:"xmark.circle") }.accessibilityLabel("Dismiss recovery notice") } }
                    if selecting {
                        HStack {
                            Button(items.count>20 ? "Select first 20 shown" : "Select shown") { selection = Set(items.prefix(20).map(\.id)) }
                            Spacer()
                            Button("Edit together") {openPool()}.disabled(selection.isEmpty || importingBatch)
                            Button("Export \(selection.count)") { batchExport = true }.disabled(selection.isEmpty || importingBatch)
                        }.font(.caption).buttonStyle(.bordered)
                        HStack {
                            Button("Paste adjustments") { batchPaste = true }.disabled(selection.isEmpty || library.adjustmentClipboard == nil)
                            Spacer()
                            Button("Delete selected",role:.destructive) { deleteIDs = selection;confirmBulkDelete = true }.disabled(selection.isEmpty || deletingProjects)
                        }.font(.caption).buttonStyle(.bordered)
                    }
                    if library.loading { ProgressView().frame(maxWidth: .infinity) }
                    else if library.projects.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("A space for your point of view.").font(.headline)
                            Text("Open photo or video to start. Your original stays untouched, and every adjustment stays editable.").font(.subheadline).foregroundStyle(StudioStyle.secondary).lineSpacing(3)
                        }.padding(22).frame(maxWidth: .infinity,alignment: .leading).background(StudioStyle.panel,in: RoundedRectangle(cornerRadius: 22))
                    } else if items.isEmpty {
                        VStack(spacing:12) {
                            Text("No matching items").font(.headline)
                            Text("Try another search or show all media.").font(.caption).foregroundStyle(StudioStyle.secondary)
                            Button("Clear search and filters") { workspaceSearch = "";filterRaw = LibraryFilter.all.rawValue }
                        }.frame(maxWidth:.infinity).padding(22)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150),spacing: 14)],spacing: 20) {
                            ForEach(items) { project in
                                VStack(alignment:.leading,spacing:9) {
                                    ProjectThumbnail(project:project,vault:library.vault).aspectRatio(0.9,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:18)).contentShape(RoundedRectangle(cornerRadius:18))
                                        .accessibilityElement(children:.ignore).accessibilityAddTraits(.isButton)
                                        .accessibilityLabel(selecting ? "Select \(project.name)" : "Open \(project.name)")
                                        .accessibilityValue(selecting && selection.contains(project.id) ? "Selected" : "")
                                        .accessibilityAction { openOrSelect(project) }
                                        .gesture(TapGesture(count:selecting ? 1 : 2).exclusively(before:TapGesture(count:1)).onEnded { value in
                                            switch value {
                                            case .first: if selecting { openOrSelect(project) } else if !importingBatch && !deletingProjects { Task { await library.organize(project,favorite:true) } }
                                            case .second: openOrSelect(project)
                                            }
                                        })
                                        .contextMenu {
                                            if selecting && selection.contains(project.id) { selectionActions }
                                            else { projectActions(project) }
                                        } preview: {
                                            ProjectThumbnail(project:project,vault:library.vault).scaledToFit().frame(width:300,height:380).clipShape(RoundedRectangle(cornerRadius:22))
                                        }
                                        .allowsHitTesting(!importingBatch && !deletingProjects && !reverting)
                                    .overlay(alignment:.topLeading) { if selecting { Image(systemName:selection.contains(project.id) ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(selection.contains(project.id) ? StudioStyle.blue : .white).padding(10).allowsHitTesting(false).accessibilityHidden(true) } }
                                    HStack(alignment:.top,spacing:6) {
                                        VStack(alignment:.leading,spacing:5) {
                                            HStack(spacing:4) {
                                                Text(project.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                                if project.organization?.favorite == true { Image(systemName:"heart.fill").font(.caption).foregroundStyle(StudioStyle.blue) }
                                                if let rating = project.organization?.rating,rating>0 { Text("\(rating)★").font(.caption.monospacedDigit()).foregroundStyle(StudioStyle.blue) }
                                            }
                                            Text("\(project.isVideo ? "VIDEO" : (project.isRAW ? "RAW" : "PHOTO")) · \(project.width) × \(project.height)").font(.system(size:10,design:.monospaced)).foregroundStyle(StudioStyle.secondary)
                                        }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle()).onTapGesture { openOrSelect(project) }
                                        Menu {
                                            if selecting && selection.contains(project.id) { selectionActions } else { projectActions(project) }
                                        } label: { Image(systemName:"ellipsis").frame(width:32,height:32) }.accessibilityLabel("Manage \(project.name)").disabled(deletingProjects || importingBatch || favoritingProjects || reverting)
                                    }
                                }.foregroundStyle(.white)
                            }
                        }
                    }
                    HStack(spacing: 6) { Image(systemName: "lock.shield"); Text("On your device. In your hands.") }
                        .font(.caption).foregroundStyle(StudioStyle.secondary).frame(maxWidth: .infinity).padding(.vertical,12)
                }.padding(22).frame(maxWidth: 980).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(StudioStyle.ink)
            .background { HomeKeyboardDismiss(active:searchFocused && selected == nil && !archives && !info && !recovery && !batchExport && !batchPaste && copyProject == nil && pasteProject == nil) { searchFocused = false }.allowsHitTesting(false) }
            .toolbar(.hidden,for: .navigationBar)
            .safeAreaInset(edge: .bottom) { importBar }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--privacy-demo") { ExportPrivacy().save() }
                let qa = ProcessInfo.processInfo.arguments.contains("--verify-object-matte") || ProcessInfo.processInfo.arguments.contains("--verify-finish-049") || ProcessInfo.processInfo.arguments.contains("--verify-point-sampling") || ProcessInfo.processInfo.arguments.contains("--verify-mask-pose") || ProcessInfo.processInfo.arguments.contains("--verify-one-d-luts") || ProcessInfo.processInfo.arguments.contains("--verify-export-estimates") || ProcessInfo.processInfo.arguments.contains("--verify-delivery-codecs") || ProcessInfo.processInfo.arguments.contains("--verify-original-media") || ProcessInfo.processInfo.arguments.contains("--verify-look-library") || ProcessInfo.processInfo.arguments.contains("--verify-mask-precision") || ProcessInfo.processInfo.arguments.contains("--verify-tracking-corrections") || ProcessInfo.processInfo.arguments.contains("--verify-video-animation") || ProcessInfo.processInfo.arguments.contains("--verify-live-archive-paths") || ProcessInfo.processInfo.arguments.contains("--verify-export-queue") || ProcessInfo.processInfo.arguments.contains("--verify-archive-performance") || ProcessInfo.processInfo.arguments.contains("--verify-project-archive") || ProcessInfo.processInfo.arguments.contains("--verify-color-delivery") || ProcessInfo.processInfo.arguments.contains("--verify-reference-match") || ProcessInfo.processInfo.arguments.contains("--verify-photo-development") || ProcessInfo.processInfo.arguments.contains("--verify-cutout-history") || ProcessInfo.processInfo.arguments.contains("--verify-pool") || ProcessInfo.processInfo.arguments.contains("--verify-real-video") || ProcessInfo.processInfo.arguments.contains("--verify-real-media") || ProcessInfo.processInfo.arguments.contains("--verify-refinement") || ProcessInfo.processInfo.arguments.contains("--verify-color-batch") || ProcessInfo.processInfo.arguments.contains("--verify-export-privacy") || ProcessInfo.processInfo.arguments.contains("--verify-video-suite") || ProcessInfo.processInfo.arguments.contains("--verify-studio") || ProcessInfo.processInfo.arguments.contains("--verify-tracking-only") || ProcessInfo.processInfo.arguments.contains("--verify-automatic-only")
                let oldIdle = UIApplication.shared.isIdleTimerDisabled
                if qa { UIApplication.shared.isIdleTimerDisabled = true }
                defer { if qa { UIApplication.shared.isIdleTimerDisabled = oldIdle } }
                #endif
                await library.load();await library.exportQueue.load()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--color-tools-demo") {
                    let ids = Set(UserDefaults.standard.stringArray(forKey:"qa.color.looks") ?? [])
                    for look in library.looks where ids.contains(look.id.uuidString) { await library.removeLook(look) }
                    let before = Set(library.looks.map(\.id))
                    var recipe = Recipe();recipe.exposure = 0.2;recipe.lut = try? LUTVerification.example()
                    _ = await library.saveLook(name:"QA Color LUT",recipe:recipe)
                    UserDefaults.standard.set(library.looks.filter { !before.contains($0.id) }.map { $0.id.uuidString },forKey:"qa.color.looks")
                }
                if ProcessInfo.processInfo.arguments.contains("--organization-demo"),let p = await addDemo() { await library.organize(p,favorite:false,rating:0);filterRaw = LibraryFilter.all.rawValue;sortRaw = LibrarySort.edited.rawValue }
                #endif
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
                if ProcessInfo.processInfo.arguments.contains("--verify-original-media"){await OriginalMediaVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-look-library"){await LookLibraryVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-mask-precision"){await MaskPrecisionVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-tracking-corrections"){await TrackingVerification.writeCorrectionReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-video-animation"){await VideoAnimationVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-live-archive-paths") {
                    var report=(try? await library.vault.auditArchivePaths(library.projects.map(\.id))) ?? ["passed":false]
                    report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
                    if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted){try? data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("archive-path-audit.json"),options:.atomic)}
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-export-queue"){await ExportQueueVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-archive-performance"){await ProjectArchiveVerification.writePerformanceReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-project-archive") {await ProjectArchiveVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-color-delivery") {await ColorDeliveryVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-reference-match") {await ReferenceMatchVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-photo-development") {await PhotoDevelopmentVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-cutout-history") {await CutoutHistoryVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-pool") {await PoolVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--pool-demo") {editingPool=await PoolVerification.demo(library)}
                if ProcessInfo.processInfo.arguments.contains("--verify-real-media") { await RealMediaVerification.writeReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-real-video") { await RealMediaVerification.writeVideoReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-refinement") { await RefinementVerification.writeReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-object-matte") {await ObjectMatteVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-finish-049") {await Finish049Verification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-point-sampling") {await PointSamplingVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-mask-pose") {await MaskPoseVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-one-d-luts") {await OneDLUTVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-export-estimates") {await ExportEstimateVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-delivery-codecs") {await DeliveryCodecVerification.writeReport()}
                if ProcessInfo.processInfo.arguments.contains("--verify-color-batch") { await ColorBatchVerification.writeReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-export-privacy") { await ExportPrivacyVerification.writeReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-video-suite") { await VideoVerification.writeReport() }
                if ProcessInfo.processInfo.arguments.contains("--verify-studio") { await StudioVerification.run(library: library) }
                if ProcessInfo.processInfo.arguments.contains("--tracking-demo"),let url = try? await TrackingVerification.fixture() {
                    selected = await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent())
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-trim-ui") || ProcessInfo.processInfo.arguments.contains("--verify-versions-ui") || ProcessInfo.processInfo.arguments.contains("--verify-transfer-ui") || ProcessInfo.processInfo.arguments.contains("--verify-mask-ui") || ProcessInfo.processInfo.arguments.contains("--verify-brush-ui") {
                    if let project = library.projects.first(where: { $0.isVideo }) { selected = project }
                    else if let url = try? await VideoFixtures.make(profile:.standard,frames:90) { selected = await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
                }
                if ProcessInfo.processInfo.arguments.contains("--batch-demo") {
                    if ProcessInfo.processInfo.arguments.contains("--batch-paste-demo") {
                        var recipe = Recipe();recipe.exposure = 0.5
                        _ = await library.copyAdjustments(name:"Batch QA grade",recipe:recipe,sections:[.light])
                    }
                    let previous = Set(UserDefaults.standard.stringArray(forKey:"qa.batch.ids") ?? [])
                    for p in library.projects where previous.contains(p.id.uuidString) { await library.remove(p) }
                    if let trash = try? await library.vault.deletedProjects() { for entry in trash where previous.contains(entry.project.id.uuidString) { try? await library.vault.eraseDeleted(entry) } }
                    let before = Set(library.projects.map(\.id))
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BatchUI-\(UUID())")
                    if let urls = try? await Task.detached(priority:.utility,operation:{ () -> [URL] in
                        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                        let context = ImageEngine.context()
                        return try (1...2).map { i in
                            let url = folder.appendingPathComponent("Studio batch QA \(i).png")
                            let image = CIImage(color:CIColor(red:0.1*Double(i),green:0.2,blue:0.3)).cropped(to:CGRect(x:0,y:0,width:128,height:96))
                            try context.writePNGRepresentation(of:image,to:url,format:.RGBA8,colorSpace:ImageEngine.output);return url
                        }
                    }).value {
                        filterRaw = LibraryFilter.all.rawValue;beginImport(urls.map { .file($0) });await importTask?.value
                        UserDefaults.standard.set(library.projects.filter { !before.contains($0.id) }.map { $0.id.uuidString },forKey:"qa.batch.ids")
                        try? FileManager.default.removeItem(at:folder)
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--finish-person-demo") {let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("StudioPersonQA.jpg");selected=await library.add(url)}
                if ProcessInfo.processInfo.arguments.contains("--finish-video-demo") {let source=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("StudioPersonQA.jpg");if let url=try? await Task.detached(priority:.utility,operation:{try await Finish049Verification.personClip(source)}).value {selected=await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent())}}
                if ProcessInfo.processInfo.arguments.contains("--point-picker-demo"),let url=try? await Task.detached(priority:.utility,operation:{try PointSamplingVerification.fixture()}).value {selected=await library.add(url);try? FileManager.default.removeItem(at:url)}
                if ProcessInfo.processInfo.arguments.contains("--video-demo"),let url = try? await VideoFixtures.make(profile:.standard,frames:90) { selected = await library.add(url);try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
                if ProcessInfo.processInfo.arguments.contains("--original-media-ui-test"),let url=Bundle.main.url(forResource:"Sample",withExtension:"jpg") {
                    let old=library.projects.filter {$0.name=="QA Original repair"};for p in old {await library.remove(p)}
                    if var p=await library.add(url) {p.name="QA Original repair";_ = await library.save(p);originalMedia=p}
                }
                if ProcessInfo.processInfo.arguments.contains("--look-library-ui-test") {
                    let old=library.looks.filter {$0.name.hasPrefix("QA Library ")};for look in old {await library.removeLook(look)}
                    _ = await library.saveLook(name:"QA Library Amber",recipe:Recipe());_ = await library.saveLook(name:"QA Library Blue",recipe:Recipe())
                }
                if ProcessInfo.processInfo.arguments.contains("--archive-ui-test") {_ = await addDemo()}
                if ProcessInfo.processInfo.arguments.contains("--demo-editor"), let project = await addDemo() { selected = project }
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in Task { await ThumbnailCache.shared.clear() } }
            .onChange(of:picker) { _,items in
                if !items.isEmpty { beginImport(items.map { .photo($0) }) }
            }
            .fileImporter(isPresented:$files,allowedContentTypes:[.image,.rawImage,.movie,.video],allowsMultipleSelection:true) { result in
                switch result {
                case .success(let urls):beginImport(urls.map { .file($0) })
                case .failure(let error):library.error = error.localizedDescription
                }
            }
            .fullScreenCover(item:$editingPool) {pool in EditingPoolEditor(pool:pool,library:library)}
            .fullScreenCover(item: $selected) { project in PhotoEditor(project: project, library: library) }
            .sheet(isPresented:$queueSheet){ExportQueueSheet(queue:library.exportQueue)}
            .fullScreenCover(isPresented:$archives){ProjectArchiveSheet(library:library,initialSelection:archiveIDs)}
            .sheet(item:$originalMedia){project in OriginalMediaSheet(library:library,project:project)}
            .sheet(isPresented:$lookLibrary){LookLibrarySheet(library:library)}
            .sheet(isPresented:$info) { StudioAbout() }
            .sheet(isPresented:$recovery,onDismiss:{emptyBinRequested=false}) { RecentlyDeletedSheet(library:library,requestEmpty:emptyBinRequested) }
            .sheet(item:$copyProject) { project in HomeCopyAdjustmentsSheet(project:project,library:library) }
            .sheet(item:$pasteProject) { project in if let clipboard = library.adjustmentClipboard { BatchPasteSheet(library:library,projects:[project],clipboard:clipboard) } }
            .sheet(isPresented:$batchPaste) { if let clipboard = library.adjustmentClipboard { BatchPasteSheet(library:library,projects:library.projects.filter { selection.contains($0.id) },clipboard:clipboard) } }
            .sheet(isPresented:$batchExport) { BatchExportSheet(projects:library.projects.filter { selection.contains($0.id) },vault:library.vault,queue:library.exportQueue) }
            .onChange(of:library.projects.map(\.id)) { _,ids in selection.formIntersection(ids) }
            .onChange(of:scenePhase) { _,phase in if phase != .active { importTask?.cancel() } }

            .alert("Unable to complete",isPresented: Binding(get: { library.error != nil },set: { if !$0 { library.error = nil } })) { Button("OK") { library.error = nil } } message: { Text(library.error ?? "") }
            .confirmationDialog("Revert to original?",isPresented:Binding(get:{ revertProject != nil },set:{ if !$0 { revertProject = nil } }),titleVisibility:.visible) {
                Button("Revert to original",role:.destructive) { if let project = revertProject { revert(project) };revertProject = nil }
            } message: { Text("Reset color, effects, masks, framing and trim to the imported original. The current edit is kept under Looks → Versions as Before revert to original. Ratings, favourites and other saved versions remain.") }
            .confirmationDialog("Move \(deleteIDs.count) projects to Recently Deleted?",isPresented:$confirmBulkDelete,titleVisibility:.visible) {
                Button("Delete \(deleteIDs.count) projects",role:.destructive) { deleteProjects(deleteIDs) }
            } message: { Text("These Studio copies can be restored for 30 days. Originals in Photos and Files remain untouched.") }
            .confirmationDialog("Move this project to Recently Deleted?",isPresented: Binding(get: { deletion != nil },set: { if !$0 { deletion = nil } }),titleVisibility: .visible) {
                Button("Delete Studio copy",role: .destructive) { if let deletion { deleteProjects([deletion.id]) }; deletion = nil }
            } message: { Text("Your original in Photos or Files will remain. The Studio copy and its edits can be restored for 30 days.") }
        }
    }
    private var workspaceControls:some View {
        VStack(spacing:12) {
            HStack(spacing:8) {
                Image(systemName:"magnifyingglass").foregroundStyle(StudioStyle.secondary)
                TextField("Search workspace",text:$workspaceSearch).focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("workspaceSearch")
                if !workspaceSearch.isEmpty { Button { workspaceSearch = "" } label: { Image(systemName:"xmark.circle.fill").frame(width:30,height:30) }.accessibilityLabel("Clear workspace search") }
            }.padding(12).background(StudioStyle.panel,in:RoundedRectangle(cornerRadius:14))
            HStack {
                Menu {
                    ForEach(LibraryFilter.allCases) { item in Button { filterRaw = item.rawValue } label: { HStack { Text(item.rawValue);if filter == item { Image(systemName:"checkmark") } } } }
                } label: { Label(filter.rawValue,systemImage:"line.3.horizontal.decrease").font(.caption).padding(.vertical,8) }.accessibilityLabel("Filter workspace").accessibilityValue(filter.rawValue)
                Spacer()
                Menu {
                    ForEach(LibrarySort.allCases) { item in Button { sortRaw = item.rawValue } label: { HStack { Text(item.rawValue);if sort == item { Image(systemName:"checkmark") } } } }
                } label: { Label(sort.rawValue,systemImage:"arrow.up.arrow.down").font(.caption).padding(.vertical,8) }.accessibilityLabel("Sort workspace").accessibilityValue(sort.rawValue)
            }
            HStack {
                Button { searchFocused = false;emptyBinRequested=false;recovery = true } label: { Label("Recently Deleted",systemImage:"trash.arrow.up") }.accessibilityLabel("Recently Deleted")
                    .contextMenu {
                        Button("Open Recently Deleted"){searchFocused=false;emptyBinRequested=false;recovery=true}
                        Button("Empty Bin…",systemImage:"trash.slash",role:.destructive){searchFocused=false;emptyBinRequested=true;recovery=true}
                    }
                    .accessibilityAction(named:Text("Empty Bin")){searchFocused=false;emptyBinRequested=true;recovery=true}
                Button("Backups"){openBackups(selection)}.accessibilityLabel("Project backups")
                Spacer()
                Menu {
                    Button("Delete selected",role:.destructive) { deleteIDs = selection;confirmBulkDelete = true }.disabled(selection.isEmpty)
                    Button("Delete all projects…",role:.destructive) { deleteIDs = Set(library.projects.map(\.id));confirmBulkDelete = true }.disabled(library.projects.isEmpty)
                } label: { Label(deletingProjects ? "Deleting…" : "Delete",systemImage:"trash") }.disabled(deletingProjects || importingBatch)
            }.font(.caption).buttonStyle(.bordered)
        }
    }
    @ViewBuilder private var selectionActions:some View {
        Button("Back up selected",systemImage:"externaldrive"){openBackups(selection)}
        Button("Favourite selected",systemImage:"heart") { organizeSelected(favorite:true) }.disabled(favoritingProjects)
        Button("Remove selected favourites",systemImage:"heart.slash") { organizeSelected(favorite:false) }.disabled(favoritingProjects)
        Menu("Rate selected",systemImage:"star") {
            Button("No rating") { organizeSelected(rating:0) }
            ForEach(1...5,id:\.self) { value in Button("\(value) \(value == 1 ? "star" : "stars")") { organizeSelected(rating:value) } }
        }.disabled(favoritingProjects)
        Button("Paste adjustments",systemImage:"doc.on.clipboard") { batchPaste = true }.disabled(library.adjustmentClipboard == nil)
        Button("Edit together",systemImage:"rectangle.stack") {openPool()}
        Button("Export selected",systemImage:"square.and.arrow.up") { batchExport = true }
        Button("Delete selected",systemImage:"trash",role:.destructive) { deleteIDs = selection;confirmBulkDelete = true }
    }
    @ViewBuilder private func projectActions(_ project:Project) -> some View {
        Button("Original media & repair",systemImage:"checkmark.shield"){searchFocused=false;originalMedia=project}
        Button("Back up project",systemImage:"externaldrive"){openBackups([project.id])}
        Button("Copy adjustments",systemImage:"doc.on.doc") { searchFocused = false;copyProject = project }
        Button("Paste adjustments",systemImage:"doc.on.clipboard") { searchFocused = false;pasteProject = project }.disabled(library.adjustmentClipboard == nil)
        Button("Revert to original",systemImage:"arrow.uturn.backward",role:.destructive) { searchFocused = false;revertProject = project }.disabled(project.recipe == project.originalRecipe || reverting)
        Button("Select project",systemImage:"checkmark.circle") { searchFocused = false;selecting = true;selection.insert(project.id) }
        Button(project.organization?.favorite == true ? "Remove favorite" : "Mark favorite",systemImage:"heart") { Task { await library.organize(project,favorite:project.organization?.favorite != true) } }
        Menu("Rate",systemImage:"star") {
            Button("No rating") { Task { await library.organize(project,rating:0) } }
            ForEach(1...5,id:\.self) { value in Button("\(value) \(value == 1 ? "star" : "stars")") { Task { await library.organize(project,rating:value) } } }
        }
        Button("Delete Studio copy",systemImage:"trash",role:.destructive) { deletion = project }
    }
    private func revert(_ project:Project) {
        guard !reverting else { return };reverting = true
        Task { @MainActor in
            defer { reverting = false }
            do {
                let updated = try await library.vault.revertToOriginal(project.id)
                if let index = library.projects.firstIndex(where:{ $0.id == updated.id }) { library.projects[index] = updated }
            } catch { library.error = error.localizedDescription }
        }
    }
    private func openBackups(_ ids:Set<UUID>) {
        searchFocused=false;archiveIDs=ids;archives=true
    }
    private func organizeSelected(favorite:Bool? = nil,rating:Int? = nil) {
        guard !favoritingProjects else { return }
        let projects = library.projects.filter { selection.contains($0.id) }
        favoritingProjects = true
        Task { @MainActor in
            defer { favoritingProjects = false }
            for project in projects { await library.organize(project,favorite:favorite,rating:rating);if library.error != nil { break } }
        }
    }
    private func deleteProjects(_ ids:Set<UUID>) {
        let projects = library.projects.filter { ids.contains($0.id) }
        deletingProjects = true
        Task { @MainActor in
            defer { deletingProjects = false }
            for project in projects { await library.remove(project);if library.error != nil { break } }
        }
    }
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Image("Hero").resizable().scaledToFill().frame(width: geometry.size.width,height: geometry.size.height).clipped().allowsHitTesting(false)
            }
            LinearGradient(colors: [.clear,.black.opacity(0.5),.black.opacity(0.95)],startPoint: .top,endPoint: .bottom).allowsHitTesting(false)
            VStack(alignment: .leading,spacing: 12) {
                Text("YOUR LIGHT. YOUR COLOR.").font(.system(size: 10,weight: .bold,design: .monospaced)).tracking(2).foregroundStyle(Color.white.opacity(0.8))
                Text("Make it\nyour own.").font(.system(size: 42,weight: .semibold,design: .serif)).tracking(-1)
                Button {
                    Task { demoBusy = true; selected = await addDemo(); demoBusy = false }
                } label: {
                    HStack(spacing: 8) { if demoBusy { ProgressView() } else { Image(systemName: "slider.horizontal.3") }; Text("Explore the editor"); Image(systemName: "arrow.up.right") }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal,16).padding(.vertical,12).background(.ultraThinMaterial,in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.16)))
                }.disabled(demoBusy || library.importing || importingBatch || deletingProjects || reverting).buttonStyle(.plain)
                Text("Illustrative sample · not a camera capture").font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
            }.padding(24)
        }.frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 28)).contentShape(RoundedRectangle(cornerRadius:28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.09)))
    }
    private var importBar: some View {
        let isImporting = library.importing || importingBatch || deletingProjects || reverting
        return HStack(spacing: 12) {
            PhotosPicker(selection: $picker,maxSelectionCount:20,matching:.any(of:[.images,.videos]),preferredItemEncoding: .current) {
                HStack(spacing: 9) { Image(systemName: "plus"); Text(isImporting ? "Importing…" : "Open photo or video").fontWeight(.semibold) }.frame(maxWidth: .infinity).frame(height: 54).background(StudioStyle.blue,in: Capsule()).foregroundStyle(.white)
            }.disabled(isImporting)
            Button { searchFocused = false;files = true } label: { Image(systemName: "folder").font(.title3).frame(width: 54,height: 54).background(.white.opacity(0.08),in: Circle()) }.disabled(isImporting).accessibilityLabel("Import photo or video from Files")
        }.padding(12)
            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:32,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:32,style:.continuous).stroke(.white.opacity(0.12),lineWidth:1))
            .shadow(color:.black.opacity(0.25),radius:18,y:8)
            .padding(.horizontal,16).padding(.vertical,8)
            .accessibilityIdentifier("floatingImportPanel")
    }
    private enum ImportSource { case photo(PhotosPickerItem),file(URL) }
    private func openPool() {
        let visibleIDs=Set(visibleProjects.map(\.id))
        let ordered=visibleProjects.filter {selection.contains($0.id)}+library.projects.filter {selection.contains($0.id) && !visibleIDs.contains($0.id)}
        let projects=ordered.isEmpty ? library.projects.filter {selection.contains($0.id)}:ordered
        guard !projects.isEmpty else {return};searchFocused=false;editingPool=EditingPool(projects:projects)
    }
    private func openOrSelect(_ project:Project) {
        guard !importingBatch && !deletingProjects else { return }
        searchFocused = false
        if selecting {
            if selection.contains(project.id) { selection.remove(project.id) }
            else if selection.count<20 { selection.insert(project.id) }
            else { library.error = "Select up to 20 projects in one batch." }
        } else { selected = project }
    }
    private func beginImport(_ sources:[ImportSource]) {
        guard !importingBatch,!deletingProjects,!sources.isEmpty else { return }
        guard sources.count<=20 else { library.error = "Choose up to 20 items at a time.";return }
        importingBatch = true;searchFocused = false
        if sources.count>1 { workspaceSearch = "";filterRaw = LibraryFilter.all.rawValue;sortRaw = LibrarySort.newest.rawValue }
        importTask = Task { @MainActor in
            defer { importingBatch = false;importTask = nil;picker = [] }
            var added:[Project] = [],failures:[String] = []
            for (i,source) in sources.enumerated() {
                if Task.isCancelled { break }
                while ProcessInfo.processInfo.thermalState.rawValue>=ProcessInfo.ThermalState.serious.rawValue && !Task.isCancelled {
                    importStatus = "Waiting for the phone to cool before importing…";try? await Task.sleep(for:.seconds(1))
                }
                if Task.isCancelled { break }
                importStatus = "Opening \(i+1) of \(sources.count)…"
                var temporary:URL?
                do {
                    let url:URL
                    switch source {
                    case .file(let file):url = file
                    case .photo(let item):guard let transfer = try await item.loadTransferable(type:PhotoTransfer.self) else { throw StudioError.unreadable };url = transfer.url;temporary = url
                    }
                    if !Task.isCancelled { if let p = await library.add(url) { added.append(p) } else { failures.append(library.error ?? "Could not open an item");library.error = nil } }
                } catch { failures.append(error.localizedDescription) }
                if let temporary { await Task.detached(priority:.utility) { try? FileManager.default.removeItem(at:temporary.deletingLastPathComponent()) }.value }
            }
            importStatus = "Added \(added.count) of \(sources.count)."+(Task.isCancelled ? " Remaining imports cancelled." : "")+(failures.isEmpty ? "" : " \(failures.count) could not open: \(failures.first!)")
            if sources.count == 1,let first = added.first { selected = first }
        }
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
    var deletedEntry:DeletedProject? = nil
    var maxDimension:Double = 450
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                StudioStyle.panel
                if let image { Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width,height: geometry.size.height).clipped() }
                else { Image(systemName: "photo").foregroundStyle(StudioStyle.secondary) }
            }
        }.task(id: project.modified) {
            let url:URL
            if let deletedEntry { url = await vault.deletedSource(deletedEntry) } else { url = await vault.source(project) }
            image = await ThumbnailCache.shared.image(url: url, project: project,maxDimension:maxDimension)
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
                    Text("Stillarc Studio · Object video masks · 0.51.0").font(.caption.monospaced()).foregroundStyle(StudioStyle.blue)
                    Text("People video matte processes each source frame once, up to 15 seconds, 900 frames and 48 MB. This allows fifteen seconds at 30 or 60 fps. Saved probabilities are bounded to 1536 pixels; export keeps the selected video dimensions. Cancellation, backgrounding or cooling stops an attempted analysis without replacing your edits. Fine detail and Clean edge provide reversible refinement starting points; check hair and motion over the replacement background. No model inference runs during playback or export.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Object video matte is in Masks → Add mask. Tap inside one distinct foreground object on the first full-frame preview, then Prepare & save. Studio analyses every kept frame and saves the changing outline. Enable Remove background outside mask, then Replace background for a colour, image or blur. Review the full clip: fine edges, fast motion, similar overlapping objects or disappearance can stop analysis. Nothing new is committed on failure; shorten the trim or select again after the obstruction. No model runs during playback/export.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("If tracking loses a target, Keep reliable tracking offers the usable path for review. The last reliable pose holds afterward; no hidden guess is made through the occlusion. Open Correct tracking → Jump to tracking loss, then scrub to the returning subject and correct its position, size and rotation. Undo/Redo and Clear corrections remain available.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Original media & repair is in each Home project's menu. Save a fingerprint while the source is available, then Verify original to check the file later. If it is missing or changed, Restore matching original accepts only the exact saved bytes from Files. It keeps your edits, masks, trim and versions; changed non-empty copies are retained locally. A fingerprint is not a backup: keep a complete project backup too. Checks run only when requested, slow down when thermal pressure rises and stop if the phone needs cooling.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Look library is on Home beside the info button, and in Looks & presets → Manage look library. Star your favourites, put looks into named collections, search, sort or change their library order. Back up all or selected looks, then Save / share every numbered .studiolooks part to Files. Import adds reusable grades and embedded LUTs without replacing existing looks; exact duplicates are skipped. It excludes your photos, videos, masks and project edits. Favourite, collection and order changes use a small metadata index without rewriting LUTs.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Masks now has preview-only Zoom and Fit, plus pinch/pan in Move/View mode up to 6×. Brush at the chosen magnification; Done brushing returns to navigation and reveals video playback without moving its slider off screen. Subject selection offers All subjects, Tap a subject and People · fine edges. People uses refined person matting; Tap isolates the detected object you choose. Detailed tracking favors accuracy; Efficient favors analysis speed. Analysis runs only when requested. Fine hair, occlusion and changing shapes still need review and brush/correction work.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("If a tracked mask drifts, open Masks → Correct tracking. Pause or scrub, turn on Move mask in preview and drag the handle, or use horizontal/vertical sliders. Correction points blend along the original clip time. Undo/Redo, delete a point or Clear corrections restore control without repeating analysis. Playback, versions, backups and queued exports keep those corrections. Choose Linear, Smooth or Hold for manual correction transitions; the measured tracking path stays active. Step one nominal frame at a time or jump to the previous/next correction with the arrow buttons. Open Size & rotation to manually resize or turn the tracked mask at chosen moments. New tracks pivot around the measured target centre. These corrections do not deform a changing subject silhouette.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("For video, Looks → Video animation changes exposure or fades a look, LUT or mask over time. Pause or scrub, drag the value to set a point, then choose another moment. Smooth blends gently; Linear changes at a steady rate. Undo/Redo and point deletion keep it reversible. Main exposure/effect strength remain the base. Points stay with the original clip time after trimming and travel with saved versions, backups and queued exports. They stay out of reusable presets and color-only LUTs.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Add to export queue on a photo/video or batch Export page keeps your chosen edits, size, quality and privacy settings. Start the queue when ready; it renders one delivery at a time. Closing the queue or leaving Studio pauses unfinished work. Completed exports stay available after reopening, with Share and Save to Photos. Queued source projects must remain available.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Project backups on Home saves originals, current edits, masks, stored reference/background images and saved versions into .stillarc files. Back up all includes every active project, using numbered parts when there are more than 20. The picker shows photo/video thumbnails. Choose Save to Files to keep it. Restore makes new editable copies, leaving existing projects untouched. Backups include original metadata and private images; use finished exports for public sharing. Global preset libraries, editing pools and app settings are separate.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Select projects on Home and choose Edit together. Swipe between items or use the filmstrip; edits stay individual until you choose Sync edits. Sync selected sections to selected items or the entire pool, with recoverable before versions. Resume the pool later. In Masks → Add mask, Subject & Background creates two independent regions from one on-device analysis.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Remove a photo background, then choose Replace background for a solid color, your own image, or a blurred version of the scene. Position, resize and soften it separately from your subject. Transparent backgrounds export as PNG; opaque replacements can use JPEG, PNG or HDR HEIF. Check hair and translucent edges with the saved mask controls. Duplicate a mask for another adjustment, invert it to edit the other side, or use the extra local light, tint, clarity and blur controls.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Detail → Photo development gives supported RAW files their own white balance, exposure, rendering boost, decoder noise controls and supported camera lens/highlight-recovery switches. Manual optics controls reduce color fringing. In Detail's menu, Heal repairs small spots by matching a clean patch; Clone copies it directly. Inspect detail loads a full-resolution tile on demand. HDR development keeps available bright detail; SDR proof previews the JPEG/PNG tone mapping. Choose HDR HEIF for a 10-bit HLG still on compatible screens. From an editing pool, Export pool items lets you deliver everything or select individual items.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Looks → Color Warp lets you steer a chosen color toward another hue or richness without recoloring neutral grays. Add up to four points, adjust how far each reaches, and use Edit color map only when you want to drag. Strength, double-tap reset and Undo keep changes reversible. Export size limits the longest edge without enlarging small originals. Maximum, Balanced and Compact control compression in single and pool exports; PNG stays lossless.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Looks → Reference & Match keeps a visual target beside your edit. Import a reference photo or take an edited snapshot of another project. Suggest a match offers a gentle light/color starting point; adjust its strength or reset it. Video uses the first kept frame. Reference images stay private to their project, while the match correction can join a reusable color preset or a selective Color sync. Scopes → Vectorscope offers an optional skin-hue direction; lighting and your chosen look can move colors away from it.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Recently Deleted includes Empty Bin. Hold its Home button to reach the same action quickly. Confirming permanently removes the displayed Studio copies and saved edits; originals in Photos or Files stay untouched.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Develop light, color and texture with reversible adjustments. Import from Photos or Files, save looks and export JPEG/PNG photographs or trimmed HEVC video with audio in SDR or 10-bit HLG HDR.")
                    Text("Levels sets black, white and midtones. Mark favorites, rate projects and search or filter your workspace. Dehaze reduces a washed-out veil or adds soft haze. Texture brings out fine surfaces or softens them; Clarity changes broader definition. The preview stays large, and Expand preview hides adjustments. Tap video to show playback controls. Use Scopes to inspect brightness and color. Drag crop corners to resize and drag inside to reposition. Fixed ratios stay locked; Free lets each edge change. Flips and perspective help refine your composition; every change stays reversible.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Open up to 20 photos or clips together. Select projects in the workspace to export their saved edits in one batch. Recently Deleted keeps Studio copies restorable for 30 days. Local settings recovery can repair a damaged project index, but does not replace a backup of your media. In Curves, add up to twelve points per Master/RGB channel and move them horizontally or vertically. Tap Edit curve points to adjust the graph; otherwise swipe it to scroll. Film → LUT stack combines up to three creative LUTs with separate strengths, bypass and ordering.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Drag the split divider to compare original and edit. Save complete versions under Looks to try different grades and return to a favorite.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Input also offers explicit sRGB, Display P3 and linear-sRGB interpretation for known mis-tagged files; Standard respects embedded colour metadata. Photo export offers tagged sRGB or Display P3, while HDR HEIF remains HLG Rec.2020. Match the source’s recorded Log profile under INPUT to restore normal color before grading. Import standalone 1D or 3D .cube creative LUTs: 1D shapes each color channel separately, while 3D can mix colors. Combined 1D + 3D files now stay together as one look: the first table shapes tones, then the second mixes colours. Film shows both sizes. Use display-sRGB creative LUTs; technical camera conversion belongs under Input. Film shows the LUT type and point count. Blend up to three layers in the LUT stack. Your looks supports search, rename and duplicate. Export a color-only .cube LUT to reuse compatible color changes in Stillarc Camera; Camera’s Look studio can share colour back to Studio. Use Files/AirDrop and import the .cube; this transfers colour, not camera settings or complete source edits. Export a color-only .cube LUT to reuse compatible color changes elsewhere; its sheet explains effects it cannot carry. Keep full source edits in Saved versions.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Copy selected adjustments under Looks, then paste them onto another photo or clip. Its framing, camera input and trim stay intact; undo reverses the paste.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Color → All colors has a White balance picker: tap a grey or white surface to adjust Warmth and Tint together. Curves → Levels has black and white point pickers to set the darkest and brightest endpoints from the preview. A small patch is averaged; Undo restores each action. Video uses the frame where you opened the picker. These are requested measurements, not ongoing analysis. Subject selection now includes Faces and Facial skin, using face shapes and landmarks as a starting point. Review the guide rather than assuming pixel-perfect skin recognition. Detail → Photo development offers chroma-noise cleanup with brightness-detail protection. Use Masks to brighten a face or darken part of a sky. Linear and radial shapes have soft edges, inversion and strength; the red guide is only a preview. Masks stay with this source; Radial, Brush and Subject masks can use position tracking.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Select foreground subjects or sky with one on-device analysis, then refine the saved selection. Video uses the first kept frame; subjects can use position tracking afterward. Track radial or painted masks through a video clip using a chosen target region. Analysis runs separately; saved motion drives playback and export. Automatic tracking measures position; manual size and rotation corrections refine it over time. There is no automatic deformation or pose tracking. Double-tap any slider to reset its default. Combine a mask with the previous selection using Intersect, Add or Subtract. Use Color masks to change similar colors or Luminance masks to adjust dark, middle or bright areas. Soft transitions blend the selection; the guide shows what is selected. Paint a brush mask to adjust a specific area. Eraser removes it, View restores playback controls, and undo removes a whole stroke. Brush size and softness apply to new strokes; full-resolution exports keep the detailed mask.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Label("Originals stay untouched",systemImage: "lock.shield")
                    Label("No account or upload required",systemImage: "wifi.slash")
                    Label("Preview draws only when needed",systemImage: "leaf")
                    DisclosureGroup("Sky model acknowledgements") {
                        Text((Bundle.main.url(forResource:"ModelNotices",withExtension:"txt").flatMap { try? String(contentsOf:$0,encoding:.utf8) }) ?? "Sky segmentation model: xiongzhu666; Core ML conversion: twistlabs/fotometis-sky. MIT license.").font(.caption).textSelection(.enabled)
                    }.font(.subheadline)
                    Text("Photos export as SDR JPEG/PNG or 10-bit HLG HEIF. Video delivery offers HEVC for smaller files, H.264 MP4 with AAC sound for broad SDR compatibility, and 10-bit ProRes 422 MOV on supported hardware for further editing. HEVC and ProRes support HLG HDR, with extended-range previews on compatible screens. Formats carry through pool delivery and the export queue. Apple Log/Log 2, manual Sony S-Log3/S-Gamut3.Cine, Panasonic V-Log/V-Gamut, Canon Log 3/Rec.2020, Nikon N-Log/Rec.2020, Fujifilm F-Log2/F-Gamut and DJI X9 D-Log/D-Gamut, plus HLG/PQ video inputs are supported. RAW photo support depends on Apple's decoder. People video mattes, face-guided skin selections and chroma cleanup are available within their displayed limits. Tap-selected Object video matte generates a changing outline per source frame and stops if identity becomes uncertain. Arbitrary occlusion reconstruction, video RAW, generative denoise and a multi-clip timeline are not included.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("The bundled sample is an AI-generated illustrative scene from the Stillarc Camera marketing library.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(26)
            }.background(StudioStyle.ink).navigationTitle("Stillarc Studio").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }.tint(StudioStyle.blue)
    }
}
