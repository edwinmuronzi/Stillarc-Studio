import Foundation

struct DeletedProject:Identifiable,Codable,Sendable {
    let id:UUID
    let project:Project
    let deleted:Date
}
extension ProjectVault {
    var recoveryRoot:URL { root.appendingPathComponent("recovery",isDirectory:true) }
    var trashRoot:URL { root.appendingPathComponent("trash",isDirectory:true) }
    func backupURL(_ id:UUID) -> URL { recoveryRoot.appendingPathComponent(id.uuidString+".json") }
    func writeRecoverableIndex(_ project:Project,forceBackup:Bool = false) throws {
        let data = try JSONEncoder().encode(project),backup = backupURL(project.id)
        let date = (try? backup.resourceValues(forKeys:[.contentModificationDateKey]))?.contentModificationDate
        if forceBackup || date == nil || Date().timeIntervalSince(date!)>=30 {
            try FileManager.default.createDirectory(at:recoveryRoot,withIntermediateDirectories:true)
            try data.write(to:backup,options:.atomic)
        }
        try data.write(to:root.appendingPathComponent(project.id.uuidString+".json"),options:.atomic)
    }
    func recoverableProject(_ url:URL) -> Project? {
        guard let id = UUID(uuidString:url.deletingPathExtension().lastPathComponent) else { return nil }
        do {
            let data = try Data(contentsOf:url),p = try JSONDecoder().decode(Project.self,from:data)
            guard p.id == id else { throw StudioError.unreadable }
            let backup = backupURL(id)
            if !FileManager.default.fileExists(atPath:backup.path) {
                do { try FileManager.default.createDirectory(at:recoveryRoot,withIntermediateDirectories:true);try data.write(to:backup,options:.atomic) }
                catch { recoveryMessages.append("The project opened, but its recovery copy could not be created.") }
            }
            return p
        } catch {
            do {
                let data = try Data(contentsOf:backupURL(id)),p = try JSONDecoder().decode(Project.self,from:data)
                guard p.id == id,FileManager.default.fileExists(atPath:source(p).path) else { throw StudioError.unreadable }
                let damaged = recoveryRoot.appendingPathComponent(id.uuidString+"-damaged.json")
                if let old = try? Data(contentsOf:url) { try old.write(to:damaged,options:.atomic) }
                try data.write(to:url,options:.atomic)
                recoveryMessages.append("Recovered a saved copy of \(p.name). Recent adjustments may be missing.")
                return p
            } catch { recoveryMessages.append("A project index could not be recovered. Its stored media has been kept.");return nil }
        }
    }
    func deletedProjects() throws -> [DeletedProject] {
        try FileManager.default.createDirectory(at:trashRoot,withIntermediateDirectories:true)
        var found:[DeletedProject] = []
        for folder in try FileManager.default.contentsOfDirectory(at:trashRoot,includingPropertiesForKeys:nil) {
            guard let data = try? Data(contentsOf:folder.appendingPathComponent("record.json")),let entry = try? JSONDecoder().decode(DeletedProject.self,from:data),folder.lastPathComponent == entry.id.uuidString else { continue }
            let index = root.appendingPathComponent(entry.project.id.uuidString+".json"),original = root.appendingPathComponent(entry.project.id.uuidString),media = folder.appendingPathComponent("media")
            let hasIndex = FileManager.default.fileExists(atPath:index.path),hasOriginal = FileManager.default.fileExists(atPath:original.path),hasMedia = FileManager.default.fileExists(atPath:media.path)
            if hasIndex && !hasOriginal && hasMedia {
                // An interrupted delete has not committed: restore its media.
                try FileManager.default.moveItem(at:media,to:original);try FileManager.default.removeItem(at:folder);continue
            }
            if !hasMedia && hasOriginal {
                // Complete an interrupted restore without changing source bytes.
                if !hasIndex { try writeRecoverableIndex(entry.project,forceBackup:true) }
                try FileManager.default.removeItem(at:folder);continue
            }
            if !hasIndex && hasMedia && Date().timeIntervalSince(entry.deleted)>30*24*60*60 {
                try FileManager.default.removeItem(at:folder);eraseRecoveryCopies(entry.project.id);continue
            }
            found.append(entry)
        }
        return found.sorted { $0.deleted>$1.deleted }
    }
    func moveToDeleted(_ project:Project) throws {
        let index = root.appendingPathComponent(project.id.uuidString+".json")
        let current = try JSONDecoder().decode(Project.self,from:Data(contentsOf:index))
        let entry = DeletedProject(id:UUID(),project:current,deleted:Date()),folder = trashRoot.appendingPathComponent(entry.id.uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let media = root.appendingPathComponent(project.id.uuidString),target = folder.appendingPathComponent("media")
        do {
            try JSONEncoder().encode(entry).write(to:folder.appendingPathComponent("record.json"),options:.atomic)
            try FileManager.default.moveItem(at:media,to:target)
            do { try FileManager.default.removeItem(at:index) }
            catch { try FileManager.default.moveItem(at:target,to:media);throw error }
        } catch { if !FileManager.default.fileExists(atPath:target.path) { try? FileManager.default.removeItem(at:folder) };throw error }
    }
    func restoreDeleted(_ entry:DeletedProject) throws -> Project {
        let folder = trashRoot.appendingPathComponent(entry.id.uuidString),media = folder.appendingPathComponent("media"),target = root.appendingPathComponent(entry.project.id.uuidString)
        guard !FileManager.default.fileExists(atPath:root.appendingPathComponent(entry.project.id.uuidString+".json").path) else { throw NSError(domain:"Recovery",code:1,userInfo:[NSLocalizedDescriptionKey:"This project already exists in your workspace."]) }
        let moved:Bool
        if FileManager.default.fileExists(atPath:media.path) {
            guard !FileManager.default.fileExists(atPath:target.path) else { throw StudioError.unreadable }
            try FileManager.default.moveItem(at:media,to:target);moved = true
        } else { moved = false;guard FileManager.default.fileExists(atPath:source(entry.project).path) else { throw StudioError.unreadable } }
        do { try writeRecoverableIndex(entry.project,forceBackup:true) }
        catch { if moved { try? FileManager.default.moveItem(at:target,to:media) };throw error }
        try FileManager.default.removeItem(at:folder)
        return entry.project
    }
    func eraseDeleted(_ entry:DeletedProject) throws {
        try FileManager.default.removeItem(at:trashRoot.appendingPathComponent(entry.id.uuidString))
        if !FileManager.default.fileExists(atPath:root.appendingPathComponent(entry.project.id.uuidString+".json").path) { eraseRecoveryCopies(entry.project.id) }
    }
    func recoveryNotice() -> String? { recoveryMessages.isEmpty ? nil : recoveryMessages.joined(separator:"\n") }
}

extension ProjectVault {
    func recoveredLooks() -> [SavedLook] {
        let primary = root.appendingPathComponent("looks.json"),backup = recoveryRoot.appendingPathComponent("looks.json")
        guard FileManager.default.fileExists(atPath:primary.path) else { return [] }
        do {
            let data = try Data(contentsOf:primary),looks = try JSONDecoder().decode([SavedLook].self,from:data)
            if !FileManager.default.fileExists(atPath:backup.path) { try? FileManager.default.createDirectory(at:recoveryRoot,withIntermediateDirectories:true);try? data.write(to:backup,options:.atomic) }
            return looks
        }
        catch {
            if let old = try? Data(contentsOf:primary) { try? FileManager.default.createDirectory(at:recoveryRoot,withIntermediateDirectories:true);try? old.write(to:recoveryRoot.appendingPathComponent("looks-damaged.json"),options:.atomic) }
            if let data = try? Data(contentsOf:backup),let looks = try? JSONDecoder().decode([SavedLook].self,from:data) {
                try? data.write(to:primary,options:.atomic);recoveryMessages.append("Recovered your saved looks from a recovery copy.");return looks
            }
            recoveryMessages.append("Saved looks could not be read. Their stored file and your project edits have been kept.");return []
        }
    }
    func eraseRecoveryCopies(_ id:UUID) {
        try? FileManager.default.removeItem(at:backupURL(id))
        try? FileManager.default.removeItem(at:recoveryRoot.appendingPathComponent(id.uuidString+"-damaged.json"))
    }
}
