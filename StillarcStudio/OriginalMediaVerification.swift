#if DEBUG
import Foundation
import AVFoundation
import CryptoKit

enum OriginalMediaVerification {
    static func run() async throws ->[String:Any] {
        func check(_ ok:Bool,_ text:String) throws {if !ok {throw OriginalMedia.fail("Original QA: "+text)}}
        guard let fixture=Bundle.main.url(forResource:"Sample",withExtension:"jpg") else {throw StudioError.unreadable}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("OriginalMediaQA-\(UUID())"),vault=ProjectVault(root:folder)
        defer {try? FileManager.default.removeItem(at:folder)}
        var p=try await vault.importPhoto(fixture);p.recipe.exposure=0.3;p.organization=ProjectOrganization(favorite:true,rating:4)
        let version=EditVersion(name:"Before repair");try await vault.saveVersion(p,version:version,recipe:p.recipe);p.versions=[version];p=try await vault.save(p)
        let source=await vault.source(p),bytes=try Data(contentsOf:source),before=try await vault.originalInfo(p.id)
        try check(before.fingerprint==nil && before.exists,"Legacy project must have no implicit fingerprint")
        let originalDate=try source.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate
        try check(try await vault.checkOriginal(p.id),"First fingerprint")
        let pinned=try await vault.originalInfo(p.id);try check(pinned.fingerprint?.bytes==UInt64(bytes.count),"Saved fingerprint size")
        try check(try await vault.checkOriginal(p.id),"Verification of unchanged source")
        try check(try source.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate==originalDate,"Checking changed original file")
        var bad=bytes;bad[0] ^= 1;try bad.write(to:source)
        try check(try await !vault.checkOriginal(p.id),"Changed source not detected")
        let wrong=folder.appendingPathComponent("wrong.jpg");try bad.write(to:wrong)
        do {_ = try await vault.repairOriginal(p.id,using:wrong);throw OriginalMedia.fail("Wrong source accepted")} catch let e as NSError {try check(e.localizedDescription != "Wrong source accepted","Wrong candidate rejection")}
        try check(try Data(contentsOf:source)==bad,"Failed repair replaced the existing file")
        let fixed=try await vault.repairOriginal(p.id,using:fixture)
        try check(try Data(contentsOf:source)==bytes && fixed.recipe==p.recipe && fixed.versions==p.versions && fixed.organization==p.organization,"Exact repair changed source/edits/versions/organisation")
        let preserved=try FileManager.default.contentsOfDirectory(at:source.deletingLastPathComponent(),includingPropertiesForKeys:nil).filter {$0.lastPathComponent.hasPrefix("before-repair-")}
        try check(preserved.count==1 && (try Data(contentsOf:preserved[0]))==bad,"Changed copy was not retained")
        try FileManager.default.removeItem(at:source)
        do {_ = try await vault.repairOriginal(p.id,using:wrong);throw OriginalMedia.fail("Wrong missing-source repair accepted")} catch let e as NSError {try check(e.localizedDescription != "Wrong missing-source repair accepted","Missing-source rejection")}
        try check(!FileManager.default.fileExists(atPath:source.path),"Failed missing-source repair wrote an original")
        let canceled=Task {withUnsafeCurrentTask {$0?.cancel()};return try await vault.repairOriginal(p.id,using:fixture)}
        do {_ = try await canceled.value;throw OriginalMedia.fail("Canceled repair committed")} catch is CancellationError {}
        try check(!FileManager.default.fileExists(atPath:source.path),"Canceled repair published a file")
        _ = try await vault.repairOriginal(p.id,using:fixture)
        try check(try await vault.checkOriginal(p.id),"Missing-source recovery verification")
        let assets=try FileManager.default.contentsOfDirectory(at:source.deletingLastPathComponent(),includingPropertiesForKeys:nil)
        try check(!assets.contains {$0.lastPathComponent.hasPrefix(".original-repair-")},"Repair staging leaked")
        try Data().write(to:source)
        try check(try await !vault.checkOriginal(p.id),"Empty source not detected")
        _ = try await vault.repairOriginal(p.id,using:fixture)
        try check(try Data(contentsOf:source)==bytes,"Empty source repair")
        let backup=try await vault.writeArchive([p.id]);defer {try? FileManager.default.removeItem(at:backup.deletingLastPathComponent())}
        let restored=try await vault.restoreArchive(backup),identity=try await vault.originalInfo(restored[0].id)
        try check(identity.fingerprint==pinned.fingerprint && identity.exists,"Project backup lost fingerprint")
        try check(try await vault.checkOriginal(restored[0].id),"Restored project fingerprint mismatch")
        let legacy=try await vault.importPhoto(fixture),legacySource=await vault.source(legacy);try FileManager.default.removeItem(at:legacySource)
        do {_ = try await vault.repairOriginal(legacy.id,using:fixture);throw OriginalMedia.fail("Unfingerprinted repair accepted")} catch let e as NSError {try check(e.localizedDescription != "Unfingerprinted repair accepted","No-fingerprint guard")}
        let movie=try await VideoFixtures.make(profile:.appleLog2,frames:12,audioTracks:1,width:128,height:72)
        defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        let video=try await vault.importPhoto(movie),videoSource=await vault.source(video)
        try check(try await vault.checkOriginal(video.id),"Video fingerprint")
        try FileManager.default.removeItem(at:videoSource)
        let fixedVideo=try await vault.repairOriginal(video.id,using:movie)
        let descriptor=try await VideoEngine.describe(videoSource),audio=try await AVURLAsset(url:videoSource).loadTracks(withMediaType:.audio)
        try check(fixedVideo.recipe==video.recipe && fixedVideo.video==video.video && descriptor.width==128 && descriptor.height==72 && audio.count==1,"Video repair changed interpretation, timing or audio")
        let blob=folder.appendingPathComponent("stream-test.bin"),copy=folder.appendingPathComponent("stream-copy.bin")
        FileManager.default.createFile(atPath:blob.path,contents:nil)
        let writer=try FileHandle(forWritingTo:blob),chunk=Data(repeating:171,count:OriginalMedia.chunk)
        var expected=SHA256()
        for _ in 0..<32 {try writer.write(contentsOf:chunk);expected.update(data:chunk)};try writer.close()
        let ticker=Task {@MainActor in
            var previous=Date(),maximum=0.0
            for _ in 0..<20 {try await Task.sleep(for:.milliseconds(16));let now=Date();maximum=max(maximum,now.timeIntervalSince(previous));previous=now};return maximum
        }
        let digest=try OriginalMedia.stream(blob,expected:UInt64(chunk.count*32),to:copy)
        let gap=try await ticker.value,wanted=expected.finalize().map {String(format:"%02x",$0)}.joined()
        try check(digest==wanted && (try copy.resourceValues(forKeys:[.fileSizeKey]).fileSize)==chunk.count*32,"Bounded stream copy hash/length")
        try check(gap<0.2,"Main actor stalled during stream copy")
        return ["passed":true,"streamFixtureBytes":chunk.count*32,"mainActorMaximumWakeMilliseconds":gap*1000,"videoLogAudioPreserved":true,"requestOnlyLegacyDefault":true,"hashDoesNotModifySource":true,"changedSourceDetected":true,"wrongSameSizeCandidateRejected":true,"atomicRepairAndPreservedChangedCopy":true,"missingSourceRestored":true,"emptySourceRepairAndBackup":true,"cancellationAndStagingCleanup":true,"editsVersionsOrganizationUnchanged":true,"backupFingerprintRoundTrip":true,"unfingerprintedRepairRejected":true]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("original-media-verification.json")
        try? FileManager.default.removeItem(at:url)
        var report=await Task.detached(priority:.utility){()->[String:Any] in do {return try await run()} catch {return ["passed":false,"error":error.localizedDescription]}}.value
        report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;report["thermal"]=ProcessInfo.processInfo.thermalState.rawValue
        if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
}
#endif
