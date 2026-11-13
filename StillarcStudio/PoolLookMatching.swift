import CoreImage
import SwiftUI

enum PoolLookMatching {
    static let sections:Set<AdjustmentSection>=[.color,.curves,.wheels,.mixer,.look,.lut,.texture]
    static func grade(_ target:Recipe,from reference:Recipe,source:ShotMatching.Statistics,referenceStats:ShotMatching.Statistics,protectLight:Bool,protectWB:Bool)->Recipe {
        var next=target.pasting(reference,sections:sections);next.matchGrade=nil
        var matched=ShotMatching.suggestion(source:source,reference:referenceStats,light:!protectLight,color:!protectWB,richness:true)
        let retained=retainedBalance(target,protectLight:protectLight,protectWB:protectWB)
        if protectLight {matched.exposure=retained.exposure}
        if protectWB {matched.red=retained.red;matched.green=retained.green;matched.blue=retained.blue}
        next.matchGrade=matched
        return next
    }
    static func retainedBalance(_ recipe:Recipe,protectLight:Bool,protectWB:Bool)->MatchGrade {
        let previous=(recipe.matchGrade ?? MatchGrade()).validated();var retained=MatchGrade()
        if protectLight {retained.exposure=previous.exposure*previous.amount}
        if protectWB {retained.red=1+(previous.red-1)*previous.amount;retained.green=1+(previous.green-1)*previous.amount;retained.blue=1+(previous.blue-1)*previous.amount}
        return retained
    }
    static func statistics(_ project:Project,recipe:Recipe,vault:ProjectVault) async throws ->ShotMatching.Statistics {
        try Task.checkCancellation()
        guard ProcessInfo.processInfo.thermalState.rawValue<ProcessInfo.ThermalState.serious.rawValue else {throw AutomaticSelectionEngine.error("Let Studio cool before matching. No pool edits were applied.")}
        let url=await vault.source(project),photo:PreparedPhoto
        if let video=project.video {photo=try await VideoEngine.poster(url,descriptor:video,maxDimension:640,time:recipe.video.start)}
        else {photo=try ImageEngine.open(url,maxDimension:640,raw:recipe.rawDevelopment,hdr:recipe.photoHDR == true)}
        let masks=try AutomaticMaskBitmap.prepare(recipe),background=try (recipe.background?.mode == .image ? recipe.background?.asset:nil).map {try BackgroundRendering.load($0,source:url,preview:true)}
        return try BackgroundRendering.$fullImage.withValue(background) {try AutomaticMaskBitmap.$prepared.withValue(masks) {try MaskMotion.$frame.withValue(.init(time:recipe.video.start,framing:MaskMotion.signature(recipe))) {try ShotMatching.statistics(ShotMatching.preview(photo,recipe:recipe,videoHDR:project.video != nil && recipe.video.hdr))}}}
    }
    static func prepare(reference:Project,targets:[Project],vault:ProjectVault,protectLight:Bool,protectWB:Bool,progress:@escaping @Sendable(Int) async->Void) async throws ->[PoolHistoryChange] {
        let referenceStats=try await statistics(reference,recipe:reference.recipe,vault:vault)
        var changes=[PoolHistoryChange]()
        for (index,p) in targets.prefix(20).enumerated() where p.id != reference.id {
            try Task.checkCancellation()
            var neutral=p.recipe.pasting(reference.recipe,sections:sections);neutral.matchGrade=retainedBalance(p.recipe,protectLight:protectLight,protectWB:protectWB)
            let stats=try await statistics(p,recipe:neutral,vault:vault)
            let after=grade(p.recipe,from:reference.recipe,source:stats,referenceStats:referenceStats,protectLight:protectLight,protectWB:protectWB)
            if after != p.recipe {changes.append(.init(id:p.id,before:p.recipe,after:after,sections:sections))}
            await progress(index+1)
            try await Task.sleep(for:.milliseconds(ProcessInfo.processInfo.thermalState == .fair ? 80:10))
        }
        return changes
    }
}
extension ProjectVault {
    func commitPoolMatch(_ changes:[PoolHistoryChange]) throws ->[Project] {
        try Task.checkCancellation()
        var originals=[Project](),updates=[Project](),versions=[EditVersion]()
        for change in changes {
            let p=try JSONDecoder().decode(Project.self,from:Data(contentsOf:root.appendingPathComponent(change.id.uuidString+".json")))
            guard p.recipe==change.before,(p.versions?.count ?? 0)<20 else {throw AutomaticSelectionEngine.error("A pool item changed or has 20 versions. No matching edits were applied; review it and retry.")}
            originals.append(p);var next=p;let version=EditVersion(name:"Before pool match");versions.append(version);next.versions=(p.versions ?? [])+[version];next.recipe=change.after;next.modified=Date();updates.append(next)
        }
        do {
            for (i,p) in originals.enumerated() {try Task.checkCancellation();try saveVersion(p,version:versions[i],recipe:p.recipe)}
            var saved=[Project]()
            for update in updates {try Task.checkCancellation();saved.append(try save(update))}
            return saved
        } catch {
            for (i,p) in originals.enumerated() {try? save(p);try? removeVersion(p,version:versions[i])}
            throw error
        }
    }
}
struct PoolLookMatchSheet:View {
    @Bindable var library:StudioLibrary
    @Bindable var pool:EditingPool
    let reference:Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var entire=false
    @State private var protectLight=true
    @State private var protectWB=true
    @State private var busy=false
    @State private var completed=false
    @State private var status:String?
    @State private var task:Task<Void,Never>?
    private var targets:[Project] {pool.projects(library,selected:!entire).filter {$0.id != reference.id}}
    var body:some View {
        NavigationStack {List {
            Section("Reference edit"){Text(reference.name);Text("Copy its creative colour, curves, wheels, LUTs and film texture, then calculate a gentle richness match for each target. Masks, framing, source interpretation, detail and capture settings stay individual.").font(.caption).foregroundStyle(StudioStyle.secondary)}
            Section("Targets") {Picker("Scope",selection:$entire){Text("Selected").tag(false);Text("Entire pool").tag(true)}.pickerStyle(.segmented);Text("\(targets.count) target items; reference excluded.").font(.caption)}.disabled(busy || completed)
            Section("Protect each shot") {
                Toggle("Keep individual brightness",isOn:$protectLight).accessibilityIdentifier("poolMatchProtectLight")
                Toggle("Keep individual white balance",isOn:$protectWB).accessibilityIdentifier("poolMatchProtectWB")
                Text("Exposure, warmth and tint sliders are never copied. With these protections on, the calculated match also leaves brightness and colour balance alone. Turn them off to allow a separate match correction. Preview video matching uses the first kept frame; review the full clip afterward.").font(.caption).foregroundStyle(StudioStyle.secondary)
            }.disabled(busy || completed)
            Section {if busy {ProgressView();Button("Cancel matching",role:.cancel){task?.cancel()}} else if !completed {Button("Match pool to this edit"){start()}.disabled(targets.isEmpty).accessibilityIdentifier("applyPoolLookMatch")};if let status {Text(status).font(.caption)}}
            Section {Text("All targets are analysed before saving. A failed or cancelled analysis applies nothing. Each changed item gets a Before pool match version; one pool Undo/Redo reverses or restores the complete match. This is an overall statistical starting point, not subject-aware relighting.").font(.caption).foregroundStyle(StudioStyle.secondary)}
        }.navigationTitle("Match pool look").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}.disabled(busy)}}.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .onDisappear {task?.cancel()}.onChange(of:phase){_,p in if p != .active {task?.cancel()}}
    }
    private func start() {
        let items=targets,ref=reference,l=protectLight,w=protectWB,vault=library.vault
        guard !busy,!pool.historyBusy else {return};busy=true;status=nil
        task=Task { @MainActor in
            defer {busy=false}
            do {
                let worker=Task.detached(priority:.utility){try await PoolLookMatching.prepare(reference:ref,targets:items,vault:vault,protectLight:l,protectWB:w){count in await MainActor.run {status="Analysed \(count) of \(items.count)…"}}}
                let changes=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
                try Task.checkCancellation();let saved=try await vault.commitPoolMatch(changes)
                for p in saved {if let i=library.projects.firstIndex(where:{$0.id==p.id}) {library.projects[i]=p}}
                pool.record(.init(title:"Match pool look",changes:changes));completed=true;status="Matched \(saved.count) items. Review each shot; pool Undo/Redo covers the whole match."
            } catch is CancellationError {status="Matching cancelled. No matching edits were applied."}
            catch {status=error.localizedDescription}
        }
    }
}
