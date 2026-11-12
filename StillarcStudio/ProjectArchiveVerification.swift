#if DEBUG
import Foundation
import CoreImage
import CryptoKit
import UIKit

private final class ArchiveCancellation<Value:Sendable>:@unchecked Sendable {
    let lock=NSLock();var task:Task<Value,Error>?;var requested=false
    func set(_ value:Task<Value,Error>) {lock.lock();task=value;let cancel=requested;lock.unlock();if cancel {value.cancel()}}
    func cancel() {lock.lock();requested=true;let value=task;lock.unlock();value?.cancel()}
}
enum ProjectArchiveVerification {
    static func run() async throws ->[String:Any] {
        func check(_ value:Bool,_ message:String) throws {if !value {throw ProjectArchive.fail("QA: "+message)}}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveQA-\(UUID())")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("Original.png"),context=ImageEngine.context()
        let image=CIImage(color:CIColor(red:0.2,green:0.4,blue:0.6)).cropped(to:CGRect(x:0,y:0,width:64,height:48))
        try context.writePNGRepresentation(of:image,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes=try Data(contentsOf:file),vault=ProjectVault(root:folder.appendingPathComponent("vault"))
        var p=try await vault.importPhoto(file)
        let ref=try await vault.importReference(file,project:p),bg=try await vault.importBackground(file,project:p)
        p.recipe.exposure=0.35;p.recipe.reference=ref
        p.recipe.lut=try LUTVerification.example(dimension:33)
        var warp=ColorWarp(),point=ColorWarpPoint();point.hueShift=15;warp.points=[point];p.recipe.colorWarp=warp
        var mask=LocalMask(kind:.brush),drawing=BrushDrawing();_ = drawing.begin(point:BrushPoint(x:0.4,y:0.4),radius:0.2,feather:0.5,erase:false);mask.brush=drawing;mask.exposure=0.4;p.recipe.masks=[mask]
        var background=PhotoBackground();background.mode = .image;background.asset=bg;p.recipe.background=background
        var automatic=LocalMask(kind:.subject)
        automatic.automatic=try AutomaticMaskBitmap.make(CIImage(color:.white).cropped(to:image.extent),recipe:p.recipe,videoStart:nil)
        p.recipe.masks.append(automatic)
        var organization=ProjectOrganization();organization.favorite=true;organization.rating=4;p.organization=organization
        let version=EditVersion(name:"Before warp");p.versions=[version]
        var old=p.recipe;old.colorWarp=nil;try await vault.saveVersion(p,version:version,recipe:old)
        p=try await vault.save(p)
        let movie=try await VideoFixtures.make(profile:.standard,frames:8,audioTracks:1,width:64,height:48);defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        var v=try await vault.importPhoto(movie);v.recipe.video.start=0.1;v.recipe.matchGrade=MatchGrade(exposure:0.2);v=try await vault.save(v)
        let url=try await vault.writeArchive([p.id,v.id]);defer {try? FileManager.default.removeItem(at:url.deletingLastPathComponent())}
        let manifest=try ProjectArchive.inspect(url)
        try check(manifest.projects == [p.id,v.id] && manifest.entries.count>=6,"Manifest assets/order")
        let restored=try await vault.restoreArchive(url)
        try check(restored.count==2 && Set(restored.map(\.id)).isDisjoint(with:[p.id,v.id]),"Restore overwrote identities")
        try check(restored[0].recipe==p.recipe && restored[0].organization==p.organization && restored[0].versions==p.versions,"Complete project roundtrip")
        try check(restored[1].recipe==v.recipe && restored[1].video==v.video,"Video descriptor/trim roundtrip")
        let restoredSource=await vault.source(restored[0]),restoredVideo=await vault.source(restored[1]),videoSource=await vault.source(v)
        try check(try Data(contentsOf:restoredSource)==bytes,"Original photo bytes")
        try check(try ProjectArchive.digest(restoredVideo,expected:UInt64(Data(contentsOf:videoSource).count))==ProjectArchive.digest(videoSource,expected:UInt64(Data(contentsOf:videoSource).count)),"Video bytes")
        let restoredVersion=try await vault.loadVersion(restored[0],version:version)
        try check(restoredVersion==old,"Saved version")
        try check(try Data(contentsOf:restoredSource.deletingLastPathComponent().appendingPathComponent(ref.filename)) == Data(contentsOf:(await vault.source(p)).deletingLastPathComponent().appendingPathComponent(ref.filename)),"Private reference bytes")
        _ = try BackgroundRendering.load(bg,source:restoredSource,preview:false)
        let exported=try ImageEngine.export(source:restoredSource,recipe:restored[0].recipe,format:.png);defer {try? FileManager.default.removeItem(at:exported.url)}
        try check(exported.width==64 && exported.height==48,"Restored export")
        let repeated=try await vault.restoreArchive(url);try check(Set(repeated.map(\.id)).isDisjoint(with:restored.map(\.id)),"Repeated restore identities")
        let before=try await vault.load().0.count
        let data=try Data(contentsOf:url)
        var corrupt=data;corrupt[corrupt.count-1] ^= 1
        func rejected(_ contents:Data,_ name:String) async throws {
            let target=folder.appendingPathComponent(name+".stillarc");try contents.write(to:target)
            do {_ = try await vault.restoreArchive(target);throw ProjectArchive.fail("QA accepted "+name)} catch {if error.localizedDescription.contains("QA accepted") {throw error}}
            let count=try await vault.load().0.count;try check(count==before,"Failed import added projects")
        }
        try await rejected(corrupt,"Corrupt payload")
        try await rejected(data.dropLast(),"Truncated payload")
        var trailing=data;trailing.append(0);try await rejected(trailing,"Unexpected trailing bytes")
        // Build malicious headers against the real payload; all must fail before commit.
        let length=data[ProjectArchive.magic.count..<ProjectArchive.magic.count+8].reduce(UInt64(0)){($0<<8)|UInt64($1)}
        let payload=data.dropFirst(ProjectArchive.magic.count+8+Int(length))
        func rewrite(_ m:ArchiveManifest)->Data {let header=try! JSONEncoder().encode(m);var d=ProjectArchive.magic,n=UInt64(header.count).bigEndian;withUnsafeBytes(of:&n){d.append(contentsOf:$0)};d.append(header);d.append(contentsOf:payload);return d}
        var bad=manifest;bad.entries[0].path="../outside.json";try await rejected(rewrite(bad),"Traversal path")
        bad=manifest;bad.entries[1].path=bad.entries[0].path;try await rejected(rewrite(bad),"Duplicate paths")
        bad=manifest;bad.minimumReader=999;try await rejected(rewrite(bad),"Future version")
        let cancelled=Task.detached {try Task.checkCancellation();return try await vault.restoreArchive(url)};cancelled.cancel()
        do {_ = try await cancelled.value;throw ProjectArchive.fail("QA cancellation ignored")} catch is CancellationError {} 
        let after=try await vault.load().0.count;try check(after==before,"Cancelled restore added projects")
        let cancelRestore=ArchiveCancellation<[Project]>()
        let midRestore=Task.detached {try await vault.restoreArchive(url,progress:{_,_ in cancelRestore.cancel()})};cancelRestore.set(midRestore)
        do {_ = try await midRestore.value;throw ProjectArchive.fail("QA mid-restore cancellation ignored")} catch is CancellationError {}
        let cancelBackup=ArchiveCancellation<URL>()
        let midBackup=Task.detached {try await vault.writeArchive([p.id,v.id],progress:{_,_ in cancelBackup.cancel()})};cancelBackup.set(midBackup)
        do {_ = try await midBackup.value;throw ProjectArchive.fail("QA mid-backup cancellation ignored")} catch is CancellationError {}
        let stillCount=try await vault.load().0.count;try check(stillCount==before,"Interrupted operation changed projects")
        // File enumeration resolves symlink aliases on iOS (/var vs /private/var).
        let actual=folder.appendingPathComponent("actual-vault"),alias=folder.appendingPathComponent("alias-vault")
        try FileManager.default.createDirectory(at:actual,withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:alias,withDestinationURL:actual)
        let aliased=ProjectVault(root:alias);var ids:[UUID]=[]
        for _ in 0..<21 {ids.append(try await aliased.importPhoto(file).id)}
        let parts=try await aliased.writeArchiveSet(ids);defer {if let first=parts.first {try? FileManager.default.removeItem(at:first.deletingLastPathComponent())}}
        try check(parts.count==2,"Backup all part count")
        let restoredPart1=try await aliased.restoreArchive(parts[0]),restoredPart2=try await aliased.restoreArchive(parts[1])
        try check(restoredPart1.count==20 && restoredPart2.count==1,"Backup all skipped projects")
        let restoredBytes=try Data(contentsOf:await aliased.source(restoredPart2[0]))
        try check(restoredBytes==bytes,"Aliased-root byte roundtrip")
        do {_ = try ProjectArchive.relativePath(folder.deletingLastPathComponent().appendingPathComponent("outside.png"),inside:actual);throw ProjectArchive.fail("QA outside root accepted")} catch {if error.localizedDescription.contains("QA outside") {throw error}}
        let current=try JSONDecoder().decode(Project.self,from:Data(contentsOf:vault.root.appendingPathComponent(p.id.uuidString+".json")))
        try check(current==p && Data(contentsOf:file)==bytes,"Existing source/project changed")
        return ["passed":true,"photoVideoSourceBytes":true,"editsMasksLUTWarp":true,"privateReferenceBackground":true,"versionsAndRatings":true,"newIdentitiesAndRepeatedRestore":true,"restoredExport":true,"corruptionTruncationTrailing":true,"traversalDuplicateFutureRejected":true,"cancelledRestoreSafe":true,"midStreamCancellation":true,"symlinkRootRoundtrip":true,"backupAll21ProjectsTwoParts":true,"projectCount":after,"packageBytes":data.count]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("project-archive-verification.json")
        try? FileManager.default.removeItem(at:url)
        let began=Date()
        let report=await Task.detached(priority:.utility){()->[String:Any] in do {return try await run()} catch {return ["passed":false,"error":error.localizedDescription]}}.value
        var result=report;result["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;result["thermal"]=ProcessInfo.processInfo.thermalState.rawValue;result["seconds"]=Date().timeIntervalSince(began)
        if let data=try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
    @MainActor static func writePerformanceReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("project-archive-performance.json")
        try? FileManager.default.removeItem(at:url)
        let idle=UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled=true
        defer {UIApplication.shared.isIdleTimerDisabled=idle}
        let monitor=Task {@MainActor in
            var delays:[Double]=[],peak=ProcessInfo.processInfo.thermalState.rawValue
            while !Task.isCancelled {let start=Date();do {try await Task.sleep(for:.milliseconds(16))} catch {break};delays.append(Date().timeIntervalSince(start));peak=max(peak,ProcessInfo.processInfo.thermalState.rawValue)}
            return (delays,peak)
        }
        let began=Date()
        var result=await Task.detached(priority:.utility){()->[String:Any] in
            let folder=FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveLargeQA-\(UUID())")
            do {
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:folder)}
                let file=folder.appendingPathComponent("source.png")
                try ImageEngine.context().writePNGRepresentation(of:CIImage(color:.gray).cropped(to:CGRect(x:0,y:0,width:32,height:32)),to:file,format:.RGBA8,colorSpace:ImageEngine.output)
                let vault=ProjectVault(root:folder.appendingPathComponent("vault")),project=try await vault.importPhoto(file)
                let payload=(await vault.source(project)).deletingLastPathComponent().appendingPathComponent("large-fixture.bin")
                FileManager.default.createFile(atPath:payload.path,contents:nil)
                let handle=try FileHandle(forWritingTo:payload),chunk=Data(repeating:0x5a,count:ProjectArchive.chunk)
                for _ in 0..<256 {try Task.checkCancellation();try handle.write(contentsOf:chunk)};try handle.close()
                let packStart=Date(),package=try await vault.writeArchive([project.id]);defer {try? FileManager.default.removeItem(at:package.deletingLastPathComponent())}
                let packed=Date().timeIntervalSince(packStart),restoreStart=Date(),restored=try await vault.restoreArchive(package)
                let restoredFile=(await vault.source(restored[0])).deletingLastPathComponent().appendingPathComponent("large-fixture.bin")
                let size=try restoredFile.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                return ["passed":size==134_217_728,"payloadBytes":size,"chunkBytes":ProjectArchive.chunk,"packSeconds":packed,"restoreSeconds":Date().timeIntervalSince(restoreStart)]
            } catch {return ["passed":false,"error":error.localizedDescription]}
        }.value
        monitor.cancel();let (delays,peak)=await monitor.value
        result["maxMainActorWakeSeconds"]=delays.max() ?? 0;result["heartbeatSamples"]=delays.count;result["thermalPeak"]=peak;result["thermalEnd"]=ProcessInfo.processInfo.thermalState.rawValue;result["seconds"]=Date().timeIntervalSince(began);result["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
        if let data=try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }

}
#endif
