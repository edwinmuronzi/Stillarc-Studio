#if DEBUG
import CoreImage
import Foundation

actor BatchProgressProbe {
    var completions = 0
    func record(_ fraction:Double) { if fraction == 1 { completions += 1 } }
}
enum Batch021Verification {
    static func run() async throws -> [String:Any] {
        func check(_ value:Bool,_ text:String) throws { if !value { throw NSError(domain:"Batch021",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Batch021-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("sample.png"),bounds = CGRect(x:0,y:0,width:64,height:48)
        let context = ImageEngine.context(),image = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:bounds)
        try context.writePNGRepresentation(of:image,to:url,format:.RGBA8,colorSpace:ImageEngine.output)
        let transfer = try PhotoTransfer.copied(url)
        try check(transfer.url.lastPathComponent == url.lastPathComponent && transfer.url != url,"Import copy lost the original filename")
        try FileManager.default.removeItem(at:transfer.url.deletingLastPathComponent())
        let original = try Data(contentsOf:url),vault = ProjectVault(root:root.appendingPathComponent("vault"))
        var a = try await vault.importPhoto(url),b = try await vault.importPhoto(url)
        a.name = "../A: photo";a.recipe.exposure = 1;b.name = a.name;b.recipe.crop = .square
        _ = try await vault.save(a);_ = try await vault.save(b)
        let probe = BatchProgressProbe()
        var missing = b;missing.id = UUID();missing.name = "Missing test source"
        let batch = try await BatchExportEngine.run([a,b,missing],vault:vault,format:.png) { _,fraction,_ in await probe.record(fraction) }
        defer { try? FileManager.default.removeItem(at:batch.folder) }
        try check(batch.urls.count == 2 && batch.failures.count == 1,"Partial batch did not preserve successes")
        try check(Set(batch.urls).count == 2 && batch.urls.allSatisfy { $0.deletingLastPathComponent() == batch.folder },"Batch filename collision or traversal")
        let first = try ImageEngine.open(batch.urls[0]),second = try ImageEngine.open(batch.urls[1])
        try check(first.width == 64 && first.height == 48 && second.width == 48 && second.height == 48,"Per-project crop was not kept")
        var p = [Float](repeating:0,count:4)
        context.render(first.image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:4,y:4,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
        try check(abs(p[0]-0.36)<0.012,"Batch lost per-project grade")
        let completions = await probe.completions;try check(completions == 3,"Batch progress did not finish each item")
        let cancel = Task { try await BatchExportEngine.run([a,b],vault:vault,format:.png,progress:{ _,_,_ in }) };cancel.cancel()
        do { let unwanted = try await cancel.value;try? FileManager.default.removeItem(at:unwanted.folder);throw StudioError.render } catch is CancellationError {}
        // Preserve recipe, organization and version files through deletion and restoration.
        let version = EditVersion(name:"Before deletion");a.versions = [version]
        try await vault.saveVersion(a,version:version,recipe:a.recipe);_ = try await vault.save(a)
        let marked = try await vault.updateOrganization(a.id,favorite:true,rating:5)
        let primary = await vault.root.appendingPathComponent(a.id.uuidString+".json"),backup = await vault.backupURL(a.id)
        let goodBackup = try Data(contentsOf:backup)
        var later = marked;later.recipe.exposure = 0.8;_ = try await vault.save(later)
        try check(try Data(contentsOf:backup) == goodBackup,"Recovery snapshot was rewritten inside its throttle interval")
        try Data("broken index".utf8).write(to:primary)
        let recovered = try await vault.load(),restoredIndex = recovered.0.first { $0.id == a.id }
        try check(restoredIndex?.recipe == marked.recipe && restoredIndex?.organization == marked.organization,"Backup did not recover edits/organization")
        let source = await vault.source(a);try check(try Data(contentsOf:source) == original,"Recovery changed source bytes")
        try await vault.remove(marked)
        var trash = try await vault.deletedProjects();guard let entry = trash.first(where:{ $0.project.id == a.id }) else { throw StudioError.render }
        let hidden = try await vault.load();try check(!hidden.0.contains(where:{ $0.id == a.id }),"Deleted item still in workspace")
        let restored = try await vault.restoreDeleted(entry)
        let savedVersion = try await vault.loadVersion(restored,version:version)
        try check(restored.organization == marked.organization && savedVersion == a.recipe && (try Data(contentsOf:source)) == original,"Restore lost media/versions/metadata")
        // Simulate a crash before the delete's index removal: load must roll the media move back.
        let validIndex = try Data(contentsOf:primary)
        try await vault.remove(restored);try validIndex.write(to:primary)
        _ = try await vault.load()
        try check(FileManager.default.fileExists(atPath:source.path),"Interrupted delete lost media")
        // Simulate a crash after moving restored media but before writing its index.
        try await vault.remove(restored);trash = try await vault.deletedProjects();let pending = trash.first { $0.project.id == a.id }!
        let trashFolder = await vault.trashRoot.appendingPathComponent(pending.id.uuidString)
        let restoredFolder = await vault.root.appendingPathComponent(a.id.uuidString)
        try FileManager.default.moveItem(at:trashFolder.appendingPathComponent("media"),to:restoredFolder)
        let resumed = try await vault.load();try check(resumed.0.contains(where:{ $0.id == a.id }),"Interrupted restore was not completed")
        // A validated old trash record expires; the external original is untouched.
        try await vault.remove(restored);trash = try await vault.deletedProjects();let expiring = trash.first { $0.project.id == a.id }!
        let expired = DeletedProject(id:expiring.id,project:expiring.project,deleted:Date().addingTimeInterval(-31*24*60*60))
        let expiredFolder = await vault.trashRoot.appendingPathComponent(expired.id.uuidString)
        try JSONEncoder().encode(expired).write(to:expiredFolder.appendingPathComponent("record.json"),options:.atomic)
        _ = try await vault.deletedProjects();try check(!FileManager.default.fileExists(atPath:expiredFolder.path),"Expired Studio copy not removed")
        try check(try Data(contentsOf:url) == original,"Batch/recovery changed the original")
        // Corrupt saved looks must not hide healthy projects.
        let look = SavedLook(name:"Recovery",recipe:b.recipe);try await vault.saveLooks([look])
        let looksURL = await vault.root.appendingPathComponent("looks.json");try Data("broken".utf8).write(to:looksURL)
        let loadedLooks = try await vault.load();try check(loadedLooks.1.first?.name == "Recovery" && loadedLooks.0.contains(where:{ $0.id == b.id }),"Saved looks recovery hid projects")
        #if !targetEnvironment(simulator)
        let clip = try await VideoFixtures.make(profile:.standard,frames:18)
        defer { try? FileManager.default.removeItem(at:clip.deletingLastPathComponent()) }
        let video = try await vault.importPhoto(clip)
        let mixed = try await BatchExportEngine.run([b,video],vault:vault,format:.png,progress:{ _,_,_ in })
        defer { try? FileManager.default.removeItem(at:mixed.folder) }
        try check(mixed.urls.count == 2 && mixed.failures.isEmpty && mixed.urls.last?.pathExtension == "mov","Mixed photo/video batch")
        #endif
        return ["passed":true,"originalImportNames":true,"partialBatch":true,"perProjectGradeCrop":true,"uniqueSafeNames":true,"cancellation":true,"indexRecovery":true,"backupThrottle":true,"restoreMediaVersionsRatings":true,"interruptedDeleteRestore":true,"trashExpiry":true,"looksRecovery":true,"originalPreserved":true]
    }
}
#endif
