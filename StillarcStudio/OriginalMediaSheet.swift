import SwiftUI

struct OriginalMediaSheet:View {
    @Bindable var library:StudioLibrary
    let project:Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var info:OriginalMediaInfo?
    @State private var result:Bool?
    @State private var message:String?
    @State private var error:String?
    @State private var files=false
    @State private var busy=false
    @State private var progress=0.0
    @State private var checkJob:Task<Bool,Error>?
    @State private var repairJob:Task<Project,Error>?
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Text(project.name).font(.headline)
                    Text(project.isVideo ? "Video original":"Photo original").foregroundStyle(StudioStyle.secondary)
                    Text("\(project.width) × \(project.height)").font(.caption.monospacedDigit())
                    if let v=project.video {Text(String(format:"%.2f s · %.2f fps",v.duration,v.frameRate)).font(.caption.monospacedDigit())}
                    Text("The Studio copy is \(info?.exists == true ? "available":"missing or being checked").").font(.subheadline)
                    if let bytes=info?.fingerprint?.bytes ?? info?.currentBytes {Text(ByteCountFormatter.string(fromByteCount:Int64(bytes),countStyle:.file)).font(.caption.monospacedDigit())}
                }
                Section {
                    Button(info?.fingerprint == nil ? "Save original fingerprint":"Verify original",systemImage:"checkmark.shield"){check()}.disabled(info?.exists != true).accessibilityIdentifier("verifyOriginalMedia")
                    Button("Restore matching original",systemImage:"arrow.triangle.2.circlepath"){files=true}.disabled(info?.fingerprint == nil || (info?.exists == true && result != false)).accessibilityIdentifier("repairOriginalMedia")
                    if busy {ProgressView(value:progress);Text("Checking bytes…").font(.caption)}
                    if let message {Text(message).font(.subheadline).foregroundStyle(result == false ? Color.orange:StudioStyle.secondary).accessibilityIdentifier("originalMediaStatus")}
                    if let error {Text(error).font(.subheadline).foregroundStyle(.orange)}
                } header:{Text("Verify and repair")} footer:{Text("A fingerprint remembers this file's exact bytes. Save one while the original is available. Verification can detect a later change; repair accepts only an exact match, keeping all edits, masks and timing. A changed local file containing data is retained as before-repair… alongside the repaired original. A fingerprint is not a backup and does not prove image quality. Existing projects without one need a project backup if their source is already missing.")}
                Section {Text("Use Home → Backups to keep complete project copies in Files. A .stillarc backup includes the fingerprint when one is saved. Checks run only on request, using bounded chunks; no background scans or media conversion.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--original-media-ui-test"),project.name=="QA Original repair",info?.fingerprint != nil {
                    Section("Test fixture only") {
                        Button("Remove test original"){Task {let url=await library.vault.source(project);try? FileManager.default.removeItem(at:url);await load()}}.accessibilityIdentifier("removeTestOriginal")
                        Button("Restore test original"){if let url=Bundle.main.url(forResource:"Sample",withExtension:"jpg"){repair(url)}}.disabled(info?.exists == true).accessibilityIdentifier("restoreTestOriginal")
                    }
                }
                #endif
            }.disabled(busy).scrollContentBackground(.hidden).background(StudioStyle.ink)
                .navigationTitle("Original media").navigationBarTitleDisplayMode(.inline)
                .toolbar {Button(busy ? "Cancel":"Done"){if busy {checkJob?.cancel();repairJob?.cancel()} else {dismiss()}}.accessibilityIdentifier("closeOriginalMedia")}
                .fileImporter(isPresented:$files,allowedContentTypes:[.item]){value in switch value {case .success(let url):repair(url);case .failure(let failure):error=failure.localizedDescription}}
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy).task {await load()}
            .onDisappear {checkJob?.cancel();repairJob?.cancel()}
            .onChange(of:phase){_,p in if p != .active {checkJob?.cancel();repairJob?.cancel()}}
    }
    private func load() async {do {info=try await library.vault.originalInfo(project.id)} catch {self.error=error.localizedDescription}}
    private func check(){
        guard !busy else {return};busy=true;progress=0;error=nil;message=nil
        let vault=library.vault,id=project.id,wasNew=info?.fingerprint==nil
        let task=Task.detached(priority:.utility){try await vault.checkOriginal(id){p in Task {@MainActor in progress=p}}};checkJob=task
        Task {@MainActor in defer {busy=false;checkJob=nil}
            do {let matches=try await task.value;result=matches;message=matches ? (wasNew ? "Fingerprint saved. Keep a project backup too.":"Verified: the original matches its saved fingerprint."):"The original has changed. Choose an exact matching file to repair it.";await load()}
            catch is CancellationError {message="Canceled. No original was replaced."} catch {self.error=error.localizedDescription;await load()}
        }
    }
    private func repair(_ url:URL){
        guard !busy else {return};busy=true;progress=0;error=nil;message=nil
        let vault=library.vault,id=project.id
        let task=Task.detached(priority:.utility){try await vault.repairOriginal(id,using:url){p in Task {@MainActor in progress=p}}};repairJob=task
        Task {@MainActor in defer {busy=false;repairJob=nil}
            do {let updated=try await task.value;if let i=library.projects.firstIndex(where:{$0.id==id}) {library.projects[i].modified=max(library.projects[i].modified,updated.modified)};await ThumbnailCache.shared.clear();result=true;message="Original restored. Saved edits and versions are unchanged.";await load()}
            catch is CancellationError {message="Canceled. No original was replaced."} catch {self.error=error.localizedDescription}
        }
    }
}
