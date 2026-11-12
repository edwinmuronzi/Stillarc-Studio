#if DEBUG
import Foundation
extension ProjectVault {
    func auditArchivePaths(_ ids:[UUID]) throws ->[String:Any] {
        var checked=0,oldRejected=0,rejected=0
        for id in ids {
            let folder=root.appendingPathComponent(id.uuidString)
            guard let enumeration=FileManager.default.enumerator(at:folder,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey],options:[.skipsHiddenFiles]) else {continue}
            for case let file as URL in enumeration {
                let value=try file.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
                guard value.isRegularFile==true else{continue};checked+=1
                let old=id.uuidString+"/media/"+String(file.path.dropFirst(folder.path.count+1))
                do {_ = try ProjectArchive.components(old,ids:[id])} catch {oldRejected+=1}
                do {guard value.isSymbolicLink != true else{throw StudioError.unreadable};let relative=try ProjectArchive.relativePath(file,inside:folder);_ = try ProjectArchive.components(id.uuidString+"/media/"+relative,ids:[id])} catch {rejected+=1}
            }
        }
        return ["passed":checked>0 && rejected==0,"checkedProjects":ids.count,"checkedAssets":checked,"previouslyRejectedPaths":oldRejected,"rejectedAfterFix":rejected]
    }
}
#endif
