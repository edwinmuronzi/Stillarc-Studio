import SwiftUI
import UniformTypeIdentifiers

struct ProjectArchiveSheet:View {
    @Bindable var library:StudioLibrary
    var initialSelection:Set<UUID>=[]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var chosen=Set<UUID>()
    @State private var restoring=false
    @State private var files=false
    @State private var incoming:URL?
    @State private var manifest:ArchiveManifest?
    @State private var result:[URL]?
    @State private var busy=false
    @State private var progress=0.0
    @State private var status=""
    @State private var message:String?
    @State private var error:String?
    @State private var task:Task<Void,Never>?
    var body:some View {
        NavigationStack {
            List {
                Picker("Backup task",selection:$restoring){Text("Back up").tag(false);Text("Restore").tag(true)}.pickerStyle(.segmented).disabled(busy)
                Section {DisclosureGroup("What’s included in a backup?") {
                    Text("Keep the original. Keep the edit.").font(.title2.weight(.semibold))
                    Text("A .stillarc backup includes original media, current edits, stored masks, references, backgrounds, ratings and saved versions. Restore it as new editable copies on a device with Stillarc Studio.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    Text("Backups include original metadata and private reference/background images. Use a finished export for public sharing. Saved look libraries, editing-pool membership and app settings are separate.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
                }
                if !restoring,let result {
                    Section(result.count==1 ? "Backup ready":"\(result.count) backup parts ready") {
                        ShareLink(items:result) {Label("Save or share backup",systemImage:"square.and.arrow.up")}.accessibilityIdentifier("shareProjectBackup")
                        #if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("--archive-ui-test"){Button("Inspect this test backup"){restoring=true;inspect(result[0])}.accessibilityIdentifier("inspectTestBackup")}
                        #endif
                        Text("Save every numbered part. Restore each part separately to recover the complete library.").font(.caption).foregroundStyle(StudioStyle.secondary)
                        Button("Make another backup"){discard();message=nil}
                        Text("Choose Save to Files to keep a copy outside Studio. Closing this page removes only the temporary file, not any copy you saved.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }
                }
                if restoring {Section("Restore a backup") {
                    Button("Choose .stillarc file",systemImage:"folder"){files=true}.disabled(busy).accessibilityIdentifier("chooseProjectBackup")
                    if let manifest,let incoming {
                        Text(incoming.lastPathComponent).font(.caption).lineLimit(2)
                        Text("\(manifest.projects.count) projects · \(ByteCountFormatter.string(fromByteCount:Int64(manifest.totalBytes),countStyle:.file))").font(.caption).foregroundStyle(StudioStyle.secondary)
                        Button("Restore \(manifest.projects.count) new copies",systemImage:"arrow.down.doc"){restore(incoming)}.disabled(busy).accessibilityIdentifier("restoreProjectBackup")
                        Text("Files are checked before projects are added. Existing projects and your Photos/Files originals stay unchanged. Restored names end in ‘Restored’.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }
                }
                }
                if !restoring && result==nil {
                    Section {
                        Text("All includes every active project. Libraries larger than 20 items create numbered backup parts; no projects are silently skipped.").font(.caption).foregroundStyle(StudioStyle.secondary)
                        HStack {Text("\(chosen.count) selected");Spacer();Button("Select up to 20"){chosen=Set(library.projects.prefix(20).map(\.id))};Button("Clear"){chosen=[]}}.font(.caption).buttonStyle(.borderless).disabled(busy)
                        ForEach(library.projects) {p in
                            Button {if !chosen.insert(p.id).inserted {chosen.remove(p.id)};if chosen.count>20 {chosen.remove(p.id);error="Choose up to 20 projects per backup."}} label:{HStack {Image(systemName:chosen.contains(p.id) ? "checkmark.circle.fill":"circle");ProjectThumbnail(project:p,vault:library.vault,maxDimension:160).frame(width:60,height:68).clipShape(RoundedRectangle(cornerRadius:10)).accessibilityHidden(true)
                            VStack(alignment:.leading,spacing:5){Text(p.name).foregroundStyle(.primary).lineLimit(2);Text(p.isVideo ? "Video":"Photo").font(.caption).foregroundStyle(StudioStyle.secondary)};Spacer()}.frame(maxWidth:.infinity,minHeight:68).contentShape(Rectangle())}.buttonStyle(.plain).disabled(busy).accessibilityLabel("Back up \(p.name)").accessibilityValue(chosen.contains(p.id) ? "Selected":"Not selected")
                        }
                    } header:{Text("Projects to back up")}
                }
                if let message {Section {Label(message,systemImage:"checkmark.circle").foregroundStyle(StudioStyle.blue)}}
                if let error {Section {Text(error).foregroundStyle(.orange)}}
                Section {Text("Keep Studio open until packing or restoring finishes. Leaving cancels unfinished work safely. Backups do not run in the background and do not re-render your media.").font(.caption).foregroundStyle(StudioStyle.secondary)}
            }.safeAreaInset(edge:.bottom) {
                if busy {VStack(spacing:8){ProgressView(value:progress);Text(status).font(.caption);Button("Cancel",role:.cancel){task?.cancel()}.accessibilityIdentifier("cancelProjectBackup")}.padding(16).frame(maxWidth:.infinity).background(.regularMaterial)}
                else if !restoring && result==nil {VStack(spacing:10) {
                    Button("Back up all (\(library.projects.count))",systemImage:"externaldrive.badge.plus"){create(all:true)}.buttonStyle(.bordered).disabled(library.projects.isEmpty).accessibilityIdentifier("backupAllProjects")
                    Button("Create backup (\(chosen.count))",systemImage:"checkmark.circle"){create()}.buttonStyle(.borderedProminent).disabled(chosen.isEmpty).accessibilityIdentifier("createProjectBackup")
                }.frame(maxWidth:.infinity).padding(12).background(.regularMaterial)}
            }.navigationTitle("Project backups").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}.disabled(busy)}
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .onAppear {chosen=initialSelection.intersection(Set(library.projects.map(\.id)))
        }
        .onDisappear {task?.cancel();discard()}
        .onChange(of:phase) {_,value in if value != .active && busy {task?.cancel()}}
        .fileImporter(isPresented:$files,allowedContentTypes:[.item]) {value in
            switch value {case .success(let url):inspect(url);case .failure(let e):error=e.localizedDescription}
        }
    }
    private func inspect(_ url:URL) {
        guard !busy else{return};busy=true;error=nil;progress=0;status="Reading backup details"
        task=Task {@MainActor in
            defer {busy=false;task=nil}
            let job=Task.detached(priority:.utility){try ProjectArchive.inspect(url)}
            do {let m=try await withTaskCancellationHandler(operation:{try await job.value},onCancel:{job.cancel()});guard !Task.isCancelled else {throw CancellationError()};incoming=url;manifest=m}
            catch is CancellationError {error="Cancelled. Your projects are unchanged."}
            catch {incoming=nil;manifest=nil;self.error=error.localizedDescription}
        }
    }
    private func create(all:Bool=false) {
        let ids=library.projects.filter {all || chosen.contains($0.id)}.map(\.id)
        let vault=library.vault
        run {progress in let url=try await vault.writeArchiveSet(ids,progress:progress);return .backup(url)}
    }
    private func restore(_ url:URL) {
        let vault=library.vault
        run {progress in let restored=try await vault.restoreArchive(url,progress:progress);return .restored(restored.count)}
    }
    private enum Outcome:Sendable {case backup([URL]),restored(Int)}
    private func run(_ work:@escaping @Sendable (@escaping @Sendable(Double,String)->Void) async throws ->Outcome) {
        guard !busy else{return};busy=true;error=nil;message=nil;progress=0;status="Preparing project files"
        task=Task {@MainActor in
            let idle=UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled=true
            defer {busy=false;task=nil;UIApplication.shared.isIdleTimerDisabled=idle}
            let job=Task.detached(priority:.utility){try await work {value,text in Task {@MainActor in progress=value;status=text}}}
            do {
                let outcome=try await withTaskCancellationHandler(operation:{try await job.value},onCancel:{job.cancel()})
                switch outcome {
                case .backup(let urls):if Task.isCancelled {if let first=urls.first {await Task.detached(priority:.utility){try? FileManager.default.removeItem(at:first.deletingLastPathComponent())}.value};throw CancellationError()};discard();result=urls;message="Backup is ready to save."
                case .restored(let count):await library.load();incoming=nil;manifest=nil;message="Restored \(count) new editable projects."
                }
            } catch is CancellationError {error="Cancelled. Existing projects and originals are safe."}
            catch {self.error=error.localizedDescription}
        }
    }
    private func discard() {guard let url=result?.first else{return};result=nil;Task.detached(priority:.utility){try? FileManager.default.removeItem(at:url.deletingLastPathComponent())}}
}
