#if DEBUG
import Foundation
import CoreImage

enum EmptyBinVerification {
    static func run() async throws -> [String:Any] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("EmptyBinQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("original.png")
        try ImageEngine.context().writePNGRepresentation(of:CIImage(color:.gray).cropped(to:CGRect(x:0,y:0,width:32,height:32)),to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes=try Data(contentsOf:file),vault=ProjectVault(root:root.appendingPathComponent("vault"))
        let a=try await vault.importPhoto(file),b=try await vault.importPhoto(file),c=try await vault.importPhoto(file)
        try await vault.remove(b);let snapshot=try await vault.deletedProjects()
        try await vault.remove(c)
        let first=try await vault.emptyDeleted(Set(snapshot.map(\.id)))
        try ReferenceMatchVerification.check(first.deleted==1 && first.failures.isEmpty,"Empty Bin result count")
        let remaining=try await vault.deletedProjects()
        try ReferenceMatchVerification.check(remaining.count==1 && remaining[0].project.id==c.id,"Empty Bin included a newly deleted item")
        _ = try await vault.restoreDeleted(remaining[0])
        let second=try await vault.emptyDeleted(Set(remaining.map(\.id)))
        let active=try await vault.load().0
        try ReferenceMatchVerification.check(second.deleted==0 && active.count==2,"Empty Bin removed a restored/live project")
        let source=await vault.source(a)
        try ReferenceMatchVerification.check(try Data(contentsOf:source)==bytes && Data(contentsOf:file)==bytes,"Empty Bin changed original/live source")
        try await vault.remove(a);try await vault.remove(c)
        let final=try await vault.emptyDeleted(Set(try await vault.deletedProjects().map(\.id)))
        let empty=try await vault.deletedProjects()
        try ReferenceMatchVerification.check(final.deleted==2 && empty.isEmpty,"Empty Bin did not clear confirmed entries")
        try ReferenceMatchVerification.check(try Data(contentsOf:file)==bytes,"External original removed")
        return ["passed":true,"confirmedSnapshotOnly":true,"restoredProjectSafe":true,"liveProjectSafe":true,"externalOriginalSafe":true,"emptyState":true]
    }
}
#endif
