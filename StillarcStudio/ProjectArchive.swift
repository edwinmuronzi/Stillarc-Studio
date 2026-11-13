import Foundation
import CryptoKit

struct ArchiveEntry:Codable,Sendable {var path:String;var bytes:UInt64;var sha256:String}
struct ArchiveManifest:Codable,Sendable {
    var format=1
    var minimumReader=55
    var projects:[UUID]
    var entries:[ArchiveEntry]
    var totalBytes:UInt64 {entries.reduce(0){$0+$1.bytes}}
}
enum ProjectArchive {
    static let magic=Data("STILLARC-BACKUP-1\n".utf8)
    static let chunk=524_288
    static func fail(_ message:String)->NSError {NSError(domain:"StudioBackup",code:1,userInfo:[NSLocalizedDescriptionKey:message])}
    static func flat(_ text:String)->Bool {!text.isEmpty && text != "." && text != ".." && !text.contains("/") && !text.contains("\\") && !text.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)})}
    static func components(_ path:String,ids:Set<UUID>) throws ->[String] {
        let c=path.components(separatedBy:"/")
        guard (c.count==2 || c.count==3 || c.count==4),c.allSatisfy(flat),let id=UUID(uuidString:c[0]),ids.contains(id),c[0]==id.uuidString else {throw fail("This backup contains an invalid file path.")}
        if c.count==2 {guard c[1]=="project.json" else {throw fail("Invalid project record.")}}
        else {guard c[1]=="media",c.count==3 || c[2]=="versions" else {throw fail("Invalid project asset path.")}}
        return c
    }
    static func relativePath(_ file:URL,inside folder:URL) throws ->String {
        let base=folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let components=file.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard components.count>base.count,Array(components.prefix(base.count))==base else {throw fail("A project asset is outside its project folder.")}
        return components.dropFirst(base.count).joined(separator:"/")
    }
    static func readExactly(_ handle:FileHandle,_ count:Int) throws ->Data {
        var data=Data();data.reserveCapacity(count)
        while data.count<count {try Task.checkCancellation();guard let part=try handle.read(upToCount:count-data.count),!part.isEmpty else {throw fail("The backup is incomplete or damaged.")};data.append(part)}
        return data
    }
    static func header(_ handle:FileHandle,fileBytes:UInt64) throws ->ArchiveManifest {
        guard try readExactly(handle,magic.count)==magic else {throw fail("Choose a Stillarc .stillarc backup file.")}
        let lengthData=try readExactly(handle,8)
        let length=lengthData.reduce(UInt64(0)){($0<<8)|UInt64($1)}
        guard length>0,length<=4_194_304,fileBytes>=UInt64(magic.count+8)+length else {throw fail("The backup header is invalid.")}
        let manifest=try JSONDecoder().decode(ArchiveManifest.self,from:readExactly(handle,Int(length)))
        guard manifest.format==1,manifest.minimumReader<=55,manifest.minimumReader>=38 else {throw fail("Update Stillarc Studio to open this backup version.")}
        guard !manifest.projects.isEmpty,manifest.projects.count<=20,Set(manifest.projects).count==manifest.projects.count,!manifest.entries.isEmpty,manifest.entries.count<=4096 else {throw fail("This backup exceeds supported project limits.")}
        var paths=Set<String>(),total:UInt64=0
        for entry in manifest.entries {
            _ = try components(entry.path,ids:Set(manifest.projects))
            guard paths.insert(entry.path).inserted,entry.bytes>0,entry.bytes<=100_000_000_000,entry.sha256.count==64,entry.sha256.allSatisfy({$0.isHexDigit}) else {throw fail("Invalid backup file record.")}
            guard total<=100_000_000_000-entry.bytes else {throw fail("This backup is too large.")};total+=entry.bytes
        }
        guard UInt64(magic.count+8)+length+total==fileBytes else {throw fail("The backup is incomplete or contains unexpected data.")}
        for id in manifest.projects {guard paths.contains(id.uuidString+"/project.json") else {throw fail("A project record is missing.")}}
        return manifest
    }
    static func inspect(_ url:URL) throws ->ArchiveManifest {
        let scoped=url.startAccessingSecurityScopedResource();defer {if scoped {url.stopAccessingSecurityScopedResource()}}
        let handle=try FileHandle(forReadingFrom:url);defer {try? handle.close()}
        return try header(handle,fileBytes:try handle.seekToEndAndRewind())
    }
    static func digest(_ url:URL,expected:UInt64,progress:(UInt64)->Void={_ in}) throws ->String {
        let input=try FileHandle(forReadingFrom:url);defer {try? input.close()}
        var hash=SHA256(),count:UInt64=0
        while let data=try input.read(upToCount:chunk),!data.isEmpty {try Task.checkCancellation();hash.update(data:data);count+=UInt64(data.count);progress(count)}
        guard count==expected else {throw fail("A project file changed while making the backup. Try again.")}
        return hash.finalize().map {String(format:"%02x",$0)}.joined()
    }
    static func validate(_ project:Project,in folder:URL) throws {
        guard flat(project.sourceName),project.name.utf8.count<=4096,project.width>0,project.height>0,project.width<=100_000,project.height<=100_000 else {throw fail("The project record is invalid.")}
        if let video=project.video {
            guard video.width>=2,video.height>=2,video.width<=4096,video.height<=4096,video.duration.isFinite,video.duration>0,video.duration<=604800,video.frameRate.isFinite,video.frameRate>0,video.frameRate<=1000,video.transform.count==6,video.transform.allSatisfy({$0.isFinite && abs($0)<=100_000}) else {throw fail("The saved video description is invalid or unsupported.")}
        }
        guard FileManager.default.fileExists(atPath:folder.appendingPathComponent(project.sourceName).path) else {throw fail("The original media is missing from this backup.")}
        func assets(_ recipe:Recipe) throws {
            for name in [recipe.reference?.filename,recipe.background?.asset?.filename].compactMap({$0}) {
                guard flat(name),FileManager.default.fileExists(atPath:folder.appendingPathComponent(name).path) else {throw fail("A saved reference or background image is missing.")}
            }
        }
        try assets(project.recipe)
        guard (project.versions?.count ?? 0)<=20 else {throw fail("Too many saved versions.")}
        for version in project.versions ?? [] {
            guard version.name.utf8.count<=4096 else {throw fail("A saved version name is too long.")}
            let url=folder.appendingPathComponent("versions").appendingPathComponent(version.id.uuidString+".json")
            let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size<=67_108_864 else {throw fail("A saved version is too large.")}
            try assets(JSONDecoder().decode(Recipe.self,from:Data(contentsOf:url)))
        }
    }
}
private extension FileHandle {
    func seekToEndAndRewind() throws ->UInt64 {let size=try seekToEnd();try seek(toOffset:0);return size}
}
extension ProjectVault {
    // Synchronous actor transaction: edits/deletion cannot mutate this snapshot during streaming.
    func writeArchive(_ ids:[UUID],progress:@Sendable(Double,String)->Void={_,_ in}) throws ->URL {
        guard !ids.isEmpty,ids.count<=20,Set(ids).count==ids.count else {throw ProjectArchive.fail("Choose between 1 and 20 projects.")}
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent("StudioBackup-\(UUID())")
        try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
        var success=false;defer {if !success {try? FileManager.default.removeItem(at:temp)}}
        var files:[(String,URL,UInt64)]=[]
        for id in ids {
            try Task.checkCancellation()
            let index=root.appendingPathComponent(id.uuidString+".json")
            guard (try index.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=67_108_864 else {throw ProjectArchive.fail("This project record is too large to back up.")}
            let data=try Data(contentsOf:index),p=try JSONDecoder().decode(Project.self,from:data),folder=root.appendingPathComponent(id.uuidString)
            guard p.id==id else {throw ProjectArchive.fail("The project record is invalid.")};try ProjectArchive.validate(p,in:folder)
            let copy=temp.appendingPathComponent(id.uuidString+".json");try data.write(to:copy,options:.atomic)
            files.append((id.uuidString+"/project.json",copy,UInt64(data.count)))
            guard let enumerator=FileManager.default.enumerator(at:folder,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey],options:[.skipsHiddenFiles]) else {throw StudioError.unreadable}
            for case let file as URL in enumerator {
                try Task.checkCancellation()
                let values=try file.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
                guard values.isSymbolicLink != true else {throw ProjectArchive.fail("Linked files cannot be included in a project backup.")}
                guard values.isRegularFile==true else {continue}
                let relative=try ProjectArchive.relativePath(file,inside:folder),path=id.uuidString+"/media/"+relative
                _ = try ProjectArchive.components(path,ids:Set(ids))
                let size=UInt64(max(0,values.fileSize ?? 0));guard size>0 else {continue}
                files.append((path,file,size));guard files.count<=4096 else {throw ProjectArchive.fail("Too many stored project assets.")}
            }
        }
        let total=files.reduce(UInt64(0)){$0+$1.2};guard total<=100_000_000_000 else {throw ProjectArchive.fail("This backup exceeds 100 GB. Choose fewer projects.")}
        var manifest=ArchiveManifest(projects:ids,entries:[]),done:UInt64=0
        var lastHash=Date.distantPast
        for (path,url,size) in files {
            try Task.checkCancellation()
            let hash=try ProjectArchive.digest(url,expected:size) {n in if Date().timeIntervalSince(lastHash)>0.15 {progress(Double(done+n)/Double(max(1,total))*0.45,"Checking project files");lastHash=Date()}}
            manifest.entries.append(ArchiveEntry(path:path,bytes:size,sha256:hash));done+=size
        }
        let header=try JSONEncoder().encode(manifest);guard header.count<=4_194_304 else {throw ProjectArchive.fail("Too many backup file records.")}
        let output=temp.appendingPathComponent("Stillarc-Projects.stillarc")
        FileManager.default.createFile(atPath:output.path,contents:nil)
        let handle=try FileHandle(forWritingTo:output);defer {try? handle.close()}
        try handle.write(contentsOf:ProjectArchive.magic)
        var length=UInt64(header.count).bigEndian;try withUnsafeBytes(of:&length){try handle.write(contentsOf:Data($0))};try handle.write(contentsOf:header)
        done=0;var last=Date.distantPast
        for (index,item) in files.enumerated() {
            let (_,file,size)=item;var copied:UInt64=0,hash=SHA256()
            let input=try FileHandle(forReadingFrom:file);defer {try? input.close()}
            while let data=try input.read(upToCount:ProjectArchive.chunk),!data.isEmpty {try Task.checkCancellation();try handle.write(contentsOf:data);hash.update(data:data);copied+=UInt64(data.count);done+=UInt64(data.count);if Date().timeIntervalSince(last)>0.15 {progress(0.45+Double(done)/Double(max(1,total))*0.55,"Packing originals and edits");last=Date()}}
            guard copied==size,hash.finalize().map({String(format:"%02x",$0)}).joined()==manifest.entries[index].sha256 else {throw ProjectArchive.fail("A project file changed during packing. Try again.")}
        }
        try Task.checkCancellation();try handle.synchronize();success=true;progress(1,"Backup ready");return output
    }
    func restoreArchive(_ url:URL,progress:@Sendable(Double,String)->Void={_,_ in}) throws ->[Project] {
        let scoped=url.startAccessingSecurityScopedResource();defer {if scoped {url.stopAccessingSecurityScopedResource()}}
        let input=try FileHandle(forReadingFrom:url);defer {try? input.close()}
        let manifest=try ProjectArchive.header(input,fileBytes:input.seekToEndAndRewind())
        let staging=FileManager.default.temporaryDirectory.appendingPathComponent("StudioRestore-\(UUID())")
        try FileManager.default.createDirectory(at:staging,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:staging)}
        var done:UInt64=0,last=Date.distantPast
        for entry in manifest.entries {
            try Task.checkCancellation()
            let target=staging.appendingPathComponent(entry.path)
            try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
            FileManager.default.createFile(atPath:target.path,contents:nil)
            let output=try FileHandle(forWritingTo:target);defer {try? output.close()}
            var remaining=entry.bytes,hash=SHA256()
            while remaining>0 {try Task.checkCancellation();let data=try ProjectArchive.readExactly(input,Int(min(UInt64(ProjectArchive.chunk),remaining)));try output.write(contentsOf:data);hash.update(data:data);remaining-=UInt64(data.count);done+=UInt64(data.count);if Date().timeIntervalSince(last)>0.15 {progress(Double(done)/Double(max(1,manifest.totalBytes))*0.9,"Checking and restoring files");last=Date()}}
            guard hash.finalize().map({String(format:"%02x",$0)}).joined()==entry.sha256.lowercased() else {throw ProjectArchive.fail("A backup file failed its integrity check. Nothing was restored.")}
        }
        var projects:[Project]=[]
        for old in manifest.projects {
            let base=staging.appendingPathComponent(old.uuidString),index=base.appendingPathComponent("project.json")
            guard (try index.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=67_108_864 else {throw ProjectArchive.fail("The project record is too large.")}
            var p=try JSONDecoder().decode(Project.self,from:Data(contentsOf:index));guard p.id==old else {throw ProjectArchive.fail("Mismatched project identity.")}
            try ProjectArchive.validate(p,in:base.appendingPathComponent("media"))
            repeat {p.id=UUID()} while projects.contains(where:{$0.id==p.id}) || FileManager.default.fileExists(atPath:root.appendingPathComponent(p.id.uuidString).path) || FileManager.default.fileExists(atPath:root.appendingPathComponent(p.id.uuidString+".json").path)
            p.name += " · Restored";projects.append(p)
        }
        try Task.checkCancellation()
        var installed:[UUID]=[]
        do {
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            for (i,p) in projects.enumerated() {
                try Task.checkCancellation();installed.append(p.id)
                try FileManager.default.moveItem(at:staging.appendingPathComponent(manifest.projects[i].uuidString).appendingPathComponent("media"),to:root.appendingPathComponent(p.id.uuidString))
                try writeRecoverableIndex(p,forceBackup:true)
            }
        } catch {
            for id in installed {try? FileManager.default.removeItem(at:root.appendingPathComponent(id.uuidString));try? FileManager.default.removeItem(at:root.appendingPathComponent(id.uuidString+".json"));eraseRecoveryCopies(id)}
            throw error
        }
        progress(1,"Projects restored");return projects
    }
}

extension ProjectVault {
    func writeArchiveSet(_ ids:[UUID],progress:@Sendable(Double,String)->Void={_,_ in}) throws ->[URL] {
        guard !ids.isEmpty,Set(ids).count==ids.count else {throw ProjectArchive.fail("Choose projects to back up.")}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("StudioBackupSet-\(UUID())")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var success=false;defer {if !success {try? FileManager.default.removeItem(at:folder)}}
        let count=(ids.count+19)/20;var outputs:[URL]=[]
        for index in 0..<count {
            try Task.checkCancellation()
            let chunk=Array(ids[(index*20)..<min(ids.count,(index+1)*20)])
            let part=try writeArchive(chunk) {value,status in progress((Double(index)+value)/Double(count),"Part \(index+1) of \(count) · "+status)}
            defer {try? FileManager.default.removeItem(at:part.deletingLastPathComponent())}
            let target=folder.appendingPathComponent(String(format:"Stillarc-Projects-%03d-of-%03d.stillarc",index+1,count))
            try FileManager.default.moveItem(at:part,to:target);outputs.append(target)
        }
        try Task.checkCancellation();success=true;progress(1,"All backup parts are ready");return outputs
    }
}
