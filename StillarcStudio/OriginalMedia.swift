import Foundation
import CryptoKit

struct OriginalFingerprint:Codable,Equatable,Sendable {
    var version=1
    var filename:String
    var bytes:UInt64
    var sha256:String
    var created=Date()
    func validate(_ project:Project) throws {
        guard version==1,filename==project.sourceName,bytes>0,bytes<=100_000_000_000,sha256.count==64,sha256.allSatisfy({$0.isHexDigit}) else {throw OriginalMedia.fail("This project's fingerprint is damaged or unsupported. Restore a project backup instead.")}
    }
}
struct OriginalMediaInfo:Sendable {var project:Project;var fingerprint:OriginalFingerprint?;var exists:Bool;var currentBytes:UInt64?}
enum OriginalMedia {
    static let recordName="original-fingerprint.json"
    static let chunk=524_288
    static func fail(_ text:String)->NSError {NSError(domain:"OriginalMedia",code:1,userInfo:[NSLocalizedDescriptionKey:text])}
    /// One bounded read; repair writes that same byte stream, without image/video decoding.
    static func stream(_ url:URL,expected:UInt64,to destination:URL?=nil,progress:@Sendable(Double)->Void={_ in}) throws ->String {
        let input=try FileHandle(forReadingFrom:url);defer {try? input.close()}
        let output:FileHandle?
        if let destination {guard FileManager.default.createFile(atPath:destination.path,contents:nil) else {throw fail("Could not prepare the repair file. Check free storage.")};output=try FileHandle(forWritingTo:destination)} else {output=nil}
        defer {try? output?.close()}
        var hash=SHA256(),count:UInt64=0,last=0.0
        while let data=try input.read(upToCount:chunk),!data.isEmpty {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.thermalState.rawValue<ProcessInfo.ThermalState.serious.rawValue else {throw fail("The phone needs to cool before checking this file. The original and saved edits are unchanged.")}
            count+=UInt64(data.count);guard count<=expected else {throw fail("The chosen file has changed or does not match the saved original.")}
            hash.update(data:data);try output?.write(contentsOf:data)
            // Only the utility worker is paced; preview/export quality is untouched.
            if ProcessInfo.processInfo.thermalState == .fair {Thread.sleep(forTimeInterval:0.004)}
            let p=Double(count)/Double(expected);if p-last>=0.01 || count==expected {progress(p);last=p}
        }
        try Task.checkCancellation();guard count==expected else {throw fail("The file is incomplete or has changed. Saved edits are unchanged.")}
        try output?.synchronize()
        return hash.finalize().map {String(format:"%02x",$0)}.joined()
    }
}
extension ProjectVault {
    private func originalProject(_ id:UUID) throws ->Project {
        let index=root.appendingPathComponent(id.uuidString+".json")
        guard (try index.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=67_108_864 else {throw OriginalMedia.fail("This project record is too large.")}
        let project=try JSONDecoder().decode(Project.self,from:Data(contentsOf:index))
        guard project.id==id,ProjectArchive.flat(project.sourceName),project.sourceName != OriginalMedia.recordName else {throw OriginalMedia.fail("This project source path is invalid.")};return project
    }
    func originalInfo(_ id:UUID) throws ->OriginalMediaInfo {
        let project=try originalProject(id),url=source(project),record=url.deletingLastPathComponent().appendingPathComponent(OriginalMedia.recordName)
        let stored:OriginalFingerprint?
        if FileManager.default.fileExists(atPath:record.path) {
            guard (try record.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=16_384 else {throw OriginalMedia.fail("The fingerprint record is invalid.")}
            stored=try JSONDecoder().decode(OriginalFingerprint.self,from:Data(contentsOf:record));try stored!.validate(project)
        } else {stored=nil}
        let exists=FileManager.default.fileExists(atPath:url.path)
        if exists {let values=try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]);guard values.isRegularFile==true,values.isSymbolicLink != true else {throw OriginalMedia.fail("The saved source is not a regular local file.")}}
        let bytes=exists ? try url.resourceValues(forKeys:[.fileSizeKey]).fileSize.map {UInt64($0)}:nil
        return OriginalMediaInfo(project:project,fingerprint:stored,exists:exists,currentBytes:bytes)
    }
    func checkOriginal(_ id:UUID,progress:@Sendable(Double)->Void={_ in}) throws ->Bool {
        let info=try originalInfo(id)
        if let record=info.fingerprint,info.currentBytes != record.bytes {return false}
        guard info.exists,let bytes=info.currentBytes,bytes>0,bytes<=100_000_000_000 else {throw OriginalMedia.fail("The original is missing or unsupported. Use a matching original file or restore a project backup.")}
        let url=source(info.project),before=try url.resourceValues(forKeys:[.contentModificationDateKey])
        let digest=try OriginalMedia.stream(url,expected:bytes,progress:progress)
        let after=try url.resourceValues(forKeys:[.contentModificationDateKey,.fileSizeKey])
        guard before.contentModificationDate==after.contentModificationDate,after.fileSize.map({UInt64($0)})==bytes else {throw OriginalMedia.fail("The original changed while checking it. Please try again.")}
        if let record=info.fingerprint {return record.sha256==digest}
        try Task.checkCancellation()
        let record=OriginalFingerprint(filename:info.project.sourceName,bytes:bytes,sha256:digest)
        try JSONEncoder().encode(record).write(to:url.deletingLastPathComponent().appendingPathComponent(OriginalMedia.recordName),options:.atomic)
        return true
    }
    func repairOriginal(_ id:UUID,using candidate:URL,progress:@Sendable(Double)->Void={_ in}) throws ->Project {
        let info=try originalInfo(id)
        guard let identity=info.fingerprint else {throw OriginalMedia.fail("No fingerprint was saved for this project. Restore its project backup; a filename or matching dimensions cannot prove this is the same original.")}
        let access=candidate.startAccessingSecurityScopedResource();defer {if access {candidate.stopAccessingSecurityScopedResource()}}
        let values=try candidate.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
        guard values.isRegularFile==true,values.fileSize.map({UInt64($0)})==identity.bytes else {throw OriginalMedia.fail("This is not the saved original. Choose the exact, unmodified file, not an exported or recompressed copy.")}
        let original=source(info.project),folder=original.deletingLastPathComponent(),staged=folder.appendingPathComponent(".original-repair-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:staged)}
        let digest=try OriginalMedia.stream(candidate,expected:identity.bytes,to:staged,progress:progress)
        guard digest==identity.sha256 else {throw OriginalMedia.fail("This file's contents do not match the original fingerprint. Nothing was replaced.")}
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath:original.path) {
            let backupName=(info.currentBytes ?? 0)>0 ? "before-repair-"+UUID().uuidString+"."+original.pathExtension:nil
            _ = try FileManager.default.replaceItemAt(original,withItemAt:staged,backupItemName:backupName,options:backupName == nil ? []:.withoutDeletingBackupItem)
        } else {try FileManager.default.moveItem(at:staged,to:original)}
        var project=info.project;project.modified=Date()
        // The original is already atomically committed. A timestamp-only index refresh
        // must not report a successful byte repair as failed (for example on a full disk).
        try? writeRecoverableIndex(project,forceBackup:true)
        return project
    }
}
