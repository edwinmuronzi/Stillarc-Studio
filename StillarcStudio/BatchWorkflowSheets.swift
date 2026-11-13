import SwiftUI
import Photos

struct BatchExportSheet:View {
    let projects:[Project]
    let vault:ProjectVault
    var queue:StudioExportQueue?=nil
    @State private var queueSheet=false
    @State private var addingQueue=false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var delivery=DeliverySettings.load()
    @State private var privacy = ExportPrivacy.load()
    @State private var format = ExportFormat.jpeg
    @State private var result:BatchExportResult?
    @State private var task:Task<BatchExportResult,Error>?
    @State private var busy = false
    @State private var saving = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var error:String?
    @State private var message:String?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text("Your edits, together.").font(.title.weight(.semibold))
                    Text("Exports each project with its own current edit, crop and masks. Video keeps its trim and HDR choice; sound follows your export privacy settings. Work runs one item at a time; originals stay untouched.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    if projects.contains(where:{ !$0.isVideo }) { Picker("Photo format",selection:$format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).disabled(busy || result != nil) }
                    DeliveryControls(settings:$delivery,lossless:format == .png && !projects.contains(where:{$0.isVideo}),video:projects.contains(where:{$0.isVideo}),photos:projects.contains(where:{!$0.isVideo}),hdr:projects.contains(where:{$0.isVideo && $0.recipe.video.hdr})).disabled(busy || result != nil)
                    if projects.contains(where:{$0.isVideo}) && delivery.codec == .h264 {Text("MP4 retains requested capture date and location. To include camera make/model, choose HEVC or ProRes MOV instead, or turn off Include camera details below.").font(.caption).foregroundStyle(privacy.camera ? .orange:StudioStyle.secondary)}
                    ExportPrivacyControls(policy:$privacy,video:projects.contains(where:{ $0.isVideo }),batch:true).disabled(busy || result != nil)
                    Text("\(projects.count) selected · full remaining source resolution").font(.caption).foregroundStyle(StudioStyle.secondary)
                    if projects.contains(where:{$0.recipe.hasTransparentCutout}) {Text("Photo cutouts always export as transparent PNG; other photos use the chosen format.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    if busy { ProgressView(value:progress);Text(status).font(.caption).lineLimit(2);Button("Cancel batch",role:.cancel) { task?.cancel() } }
                    else if let result {
                        Label("\(result.urls.count) of \(projects.count) exported",systemImage:result.urls.isEmpty ? "exclamationmark.circle" : "checkmark.circle").foregroundStyle(result.urls.isEmpty ? .orange : StudioStyle.blue)
                        if !result.urls.isEmpty {
                            ShareLink(items:result.urls) { Label("Share or save files",systemImage:"square.and.arrow.up").frame(maxWidth:.infinity).padding(14) }.buttonStyle(.borderedProminent)
                            Button(saving ? "Saving…" : "Save all to Photos") { Task { await save(result.urls) } }.disabled(saving).buttonStyle(.bordered)
                        }
                        Button("Change export options") {
                            let folder = result.folder
                            self.result = nil;message = nil;error = nil
                            Task.detached(priority:.utility) { try? FileManager.default.removeItem(at:folder) }
                        }.disabled(saving)
                        ForEach(Array(result.failures.enumerated()),id:\.offset) { _,failure in Text(failure).font(.caption).foregroundStyle(.orange) }
                    }
                    if let queue {
                        Button("Add batch to export queue",systemImage:"list.bullet.rectangle"){Task {addingQueue=true;defer {addingQueue=false};if await queue.enqueue(projects,format:format,privacy:privacy,delivery:delivery){message="Added to queue. Open it to start delivery."} else {error=queue.error}}}.disabled(busy || saving || addingQueue || result != nil).accessibilityIdentifier("enqueueBatchExport")
                        Button("Open export queue"){queueSheet=true}.disabled(busy || saving).accessibilityIdentifier("openExportQueue")
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(.orange) }
                    if let message { Text(message).font(.caption).foregroundStyle(StudioStyle.blue) }
                    Text("Leaving the app cancels an unfinished batch. Export may pause to cool the phone. Completed files remain available here until you change options or close this sheet.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(22)
            }.safeAreaInset(edge:.bottom) {
                if result == nil && !busy {
                    Button("Create batch export") { start() }.buttonStyle(.borderedProminent).accessibilityIdentifier("createBatchExport")
                        .frame(maxWidth:.infinity).padding(14).background(.regularMaterial)
                }
            }.navigationTitle("Batch export").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() }.disabled(busy || saving) }
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy || saving)
        .sheet(isPresented:$queueSheet){if let queue {ExportQueueSheet(queue:queue)}}
        .onChange(of:phase) { _,value in if value != .active && busy { task?.cancel() } }
        .onDisappear { task?.cancel();if let folder = result?.folder { Task.detached(priority:.utility) { try? FileManager.default.removeItem(at:folder) } } }
    }
    private func start() {
        busy = true;error = nil;progress = 0
        let format = format,privacy = privacy,delivery=delivery
        let job = Task.detached(priority:.utility) { try await BatchExportEngine.run(projects,vault:vault,format:format,privacy:privacy,delivery:delivery) { index,fraction,name in
            await MainActor.run { progress = (Double(index)+fraction)/Double(projects.count);status = "\(index+1) of \(projects.count) · \(name)" }
        } };task = job
        Task { @MainActor in
            defer { busy = false;task = nil }
            do { result = try await job.value }
            catch is CancellationError { error = "Batch cancelled. Your projects and originals are safe." }
            catch { self.error = error.localizedDescription }
        }
    }
    private func save(_ urls:[URL]) async {
        saving = true;error = nil;message = nil;defer { saving = false }
        let authorization = await PHPhotoLibrary.requestAuthorization(for:.addOnly)
        guard authorization == .authorized || authorization == .limited else { error = "Allow access to add media in Settings, or save the files with Share.";return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for url in urls { if VideoEngine.isMovie(url) { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:url) } else { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:url) } }
            }
            message = "Saved \(urls.count) items to Photos."
        } catch { self.error = error.localizedDescription }
    }
}
struct RecentlyDeletedSheet:View {
    @Bindable var library:StudioLibrary
    var requestEmpty=false
    @Environment(\.dismiss) private var dismiss
    @State private var entries:[DeletedProject] = []
    @State private var busy = false
    @State private var error:String?
    @State private var erase:DeletedProject?
    @State private var emptySnapshot:[DeletedProject]?
    @State private var emptyMessage:String?
    @State private var preview:DeletedProject?
    var body:some View {
        NavigationStack {
            List {
                Section { Text("Studio copies stay here for 30 days, then are removed. Restoring brings back their media, edits, ratings and saved versions. Your original in Photos or Files is unchanged.").font(.subheadline).foregroundStyle(StudioStyle.secondary) }
                Section {
                    Button("Empty Bin",systemImage:"trash.slash",role:.destructive) {emptySnapshot=entries}.disabled(busy || entries.isEmpty).accessibilityIdentifier("emptyBinButton")
                    if let emptyMessage {Text(emptyMessage).font(.caption).foregroundStyle(StudioStyle.secondary)}
                }
                if entries.isEmpty { Text("No recently deleted projects").foregroundStyle(StudioStyle.secondary) }
                ForEach(entries) { entry in
                    VStack(alignment:.leading,spacing:10) {
                        HStack(alignment:.top,spacing:14) {
                            Button { preview = entry } label: {
                                ProjectThumbnail(project:entry.project,vault:library.vault,deletedEntry:entry).frame(width:90,height:100).clipShape(RoundedRectangle(cornerRadius:14))
                            }.buttonStyle(.plain).accessibilityLabel("Preview deleted \(entry.project.name)")
                            VStack(alignment:.leading,spacing:7) {
                                Text(entry.project.name).font(.headline)
                                Text("Deleted \(entry.deleted.formatted(date:.abbreviated,time:.omitted))").font(.caption).foregroundStyle(StudioStyle.secondary)
                                Text(entry.daysRemaining() == 1 ? "1 day left" : "\(entry.daysRemaining()) days left").font(.caption.weight(.semibold)).foregroundStyle(entry.daysRemaining()<=3 ? .orange : StudioStyle.blue)
                                if entry.project.isVideo { Label("Video",systemImage:"video").font(.caption2).foregroundStyle(StudioStyle.secondary) }
                            }
                        }
                        HStack { Button("Restore") { Task { await restore(entry) } };Spacer();Button("Delete permanently",role:.destructive) { erase = entry } }.font(.caption).buttonStyle(.borderless).disabled(busy)
                    }.padding(.vertical,6)
                }
                if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            }.navigationTitle("Recently Deleted").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() }.disabled(busy) }
        }.tint(StudioStyle.blue).task {await load();if requestEmpty,!entries.isEmpty {emptySnapshot=entries}}.interactiveDismissDisabled(busy)
        .sheet(item:$preview) { entry in
            NavigationStack {
                ProjectThumbnail(project:entry.project,vault:library.vault,deletedEntry:entry)
                    .aspectRatio(CGFloat(max(1,entry.project.width))/CGFloat(max(1,entry.project.height)),contentMode:.fit)
                    .clipShape(RoundedRectangle(cornerRadius:20)).padding(20)
                    .navigationTitle(entry.project.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { preview = nil } }
            }.tint(StudioStyle.blue)
        }
        .alert("Permanently delete \(emptySnapshot?.count ?? 0) projects?",isPresented:Binding(get:{emptySnapshot != nil},set:{if !$0 {emptySnapshot=nil}})) {
            Button("Empty Bin",role:.destructive) {let ids=Set((emptySnapshot ?? []).map(\.id));emptySnapshot=nil;Task {await empty(ids)}}
            Button("Cancel",role:.cancel){emptySnapshot=nil}
        } message: {Text("This permanently removes these Studio copies and their saved edits. It cannot be undone. Originals in Photos or Files are unchanged.")}
        .confirmationDialog("Permanently delete this Studio copy?",isPresented:Binding(get:{ erase != nil },set:{ if !$0 { erase = nil } }),titleVisibility:.visible) {
            Button("Delete permanently",role:.destructive) { if let entry = erase { Task { busy = true;defer { busy = false };do { try await library.vault.eraseDeleted(entry);await load() } catch { self.error = error.localizedDescription } } };erase = nil }
        } message: { Text("This cannot be restored from Studio. Your original in Photos or Files is unchanged.") }
    }
    private func empty(_ ids:Set<UUID>) async {
        guard !busy else {return};busy=true;defer {busy=false};error=nil
        do {
            let result=try await library.vault.emptyDeleted(ids)
            emptyMessage="Permanently deleted \(result.deleted) projects."
            if !result.failures.isEmpty {error="\(result.failures.count) could not be deleted. "+result.failures.prefix(2).joined(separator:"; ")}
            await ThumbnailCache.shared.clear();await load()
        } catch {self.error=error.localizedDescription;await load()}
    }
    private func load() async { do { entries = try await library.vault.deletedProjects() } catch { self.error = error.localizedDescription } }
    private func restore(_ entry:DeletedProject) async {
        busy = true;defer { busy = false }
        do { _ = try await library.vault.restoreDeleted(entry);await library.load();await load() } catch { self.error = error.localizedDescription }
    }
}
