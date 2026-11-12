import Foundation

struct EmptyBinResult:Sendable {var deleted=0;var failures=[String]()}
extension ProjectVault {
    /// Only the IDs shown in the confirmation are eligible. Reconcile interrupted restores first.
    func emptyDeleted(_ confirmedIDs:Set<UUID>) throws -> EmptyBinResult {
        guard !confirmedIDs.isEmpty else {return EmptyBinResult()}
        let eligible=try deletedProjects().filter {confirmedIDs.contains($0.id)}
        var result=EmptyBinResult()
        for entry in eligible {
            try Task.checkCancellation()
            do {try eraseDeleted(entry);result.deleted += 1}
            catch {result.failures.append(entry.project.name+": "+error.localizedDescription)}
        }
        return result
    }
}
