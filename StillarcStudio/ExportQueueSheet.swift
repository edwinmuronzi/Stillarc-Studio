import SwiftUI
import Photos

struct ExportQueueSheet:View {
    @Bindable var queue:StudioExportQueue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var removing:UUID?
    @State private var saving:UUID?
    @State private var message:String?
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Text("Your deliveries, in order.").font(.title2.weight(.semibold))
                    Text("Each job keeps the edits and export settings you added. Start when ready. Only one job renders at a time. Closing this page or leaving the app pauses unfinished work; completed files remain here after reopening Studio.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("An interrupted job restarts from its beginning. Keep the source projects until delivery finishes. The queue never automatically starts on launch.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
                if queue.jobs.isEmpty {Text("Add a delivery from a photo/video Export page or batch export.").foregroundStyle(StudioStyle.secondary)}
                ForEach(queue.jobs) {job in
                    Section {
                        VStack(alignment:.leading,spacing:10) {
                            Text(job.title).font(.headline).lineLimit(2)
                            Text("\(job.format.rawValue) · \(job.delivery.size.rawValue) · \(job.delivery.quality.rawValue)").font(.caption).foregroundStyle(StudioStyle.secondary)
                            Text(label(job.state)).font(.caption.weight(.semibold)).foregroundStyle(job.state == .failed ? .orange:StudioStyle.blue).accessibilityIdentifier("queueState-"+job.id.uuidString)
                            if job.state == .running {ProgressView(value:queue.progress);Text(queue.status).font(.caption).lineLimit(2)}
                            if !job.files.isEmpty {
                                ShareLink(items:queue.urls(job)){Label("Share or save files",systemImage:"square.and.arrow.up")}
                                Button(saving==job.id ? "Saving…":"Save to Photos"){Task {await save(job)}}.disabled(saving != nil || queue.running)
                            }
                            ForEach(Array(job.failures.enumerated()),id:\.offset){_,text in Text(text).font(.caption).foregroundStyle(.orange)}
                            HStack {
                                if job.state == .waiting || job.state == .running {Button("Cancel job",role:.cancel){Task {await queue.cancel(job.id)}}}
                                if job.state == .failed || job.state == .cancelled {Button("Retry"){Task {await queue.retry(job.id)}}.disabled(queue.running)}
                                Spacer()
                                Menu {
                                    Button("Move earlier"){Task {await queue.move(job.id,by:-1)}}
                                    Button("Move later"){Task {await queue.move(job.id,by:1)}}
                                    Button("Remove job and export files",role:.destructive){removing=job.id}
                                } label:{Image(systemName:"ellipsis.circle").frame(width:44,height:36)}.disabled(queue.running || saving != nil).accessibilityLabel("Manage queued "+job.title)
                            }.buttonStyle(.borderless).font(.caption)
                        }.padding(.vertical,6)
                    }
                }
                if let message {Text(message).font(.caption).foregroundStyle(StudioStyle.blue)}
                if let error=queue.error {Text(error).font(.caption).foregroundStyle(.orange)}
            }.navigationTitle("Export queue").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){queue.pause();dismiss()}.disabled(saving != nil).accessibilityIdentifier("closeExportQueue")}
                .safeAreaInset(edge:.bottom) {
                    if queue.running {Button(queue.pausing ? "Pausing…":"Pause queue"){queue.pause()}.disabled(queue.pausing).buttonStyle(.borderedProminent).frame(maxWidth:.infinity).padding(16).background(.regularMaterial).accessibilityIdentifier("pauseExportQueue")}
                    else {Button("Start queue (\(queue.pending))"){queue.start()}.buttonStyle(.borderedProminent).disabled(queue.pending==0 || !queue.loaded).frame(maxWidth:.infinity).padding(16).background(.regularMaterial).accessibilityIdentifier("startExportQueue")}
                }
        }.tint(StudioStyle.blue).task {await queue.load()}.onDisappear {queue.pause()}.onChange(of:phase){_,value in if value != .active {queue.pause()}}
            .alert("Remove this delivery?",isPresented:Binding(get:{removing != nil},set:{if !$0 {removing=nil}})) {
                Button("Remove",role:.destructive){if let id=removing {Task {await queue.remove(id)}};removing=nil};Button("Cancel",role:.cancel){removing=nil}
            } message:{Text("This removes its queued settings and Studio's export files. Source projects, edits and copies already saved to Photos or Files remain unchanged.")}
    }
    private func label(_ state:QueueJobState)->String {switch state {case .waiting:"Waiting";case .running:queue.pausing ? "Pausing":"Exporting";case .completed:"Ready";case .failed:"Needs attention";case .cancelled:"Cancelled"}}
    private func save(_ job:QueueJob) async {
        saving=job.id;defer {saving=nil};message=nil
        let access=await PHPhotoLibrary.requestAuthorization(for:.addOnly)
        guard access == .authorized || access == .limited else {message="Allow Photos access in Settings, or use Share to save to Files.";return}
        let urls=queue.urls(job)
        do {try await PHPhotoLibrary.shared().performChanges {for url in urls {if url.pathExtension == "mov" {PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:url)} else {PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:url)}}};message="Saved to Photos."} catch {message=error.localizedDescription}
    }
}
