import Foundation

struct PoolHistoryChange:Sendable {
    let id:UUID
    let before:Recipe
    let after:Recipe
    var sections:Set<AdjustmentSection>? = nil
}
struct PoolHistoryStep:Sendable {
    let title:String
    let changes:[PoolHistoryChange]
}
extension ProjectVault {
    /// Preflight every destination; preserve organization and version checkpoints.
    func applyPoolHistory(_ step:PoolHistoryStep,undo:Bool) throws -> [Project] {
        var originals=[Project](),updates=[Project]()
        for change in step.changes {
            let url=root.appendingPathComponent(change.id.uuidString+".json")
            let project=try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
            var updated=project
            let expected=undo ? change.after:change.before,target=undo ? change.before:change.after
            if let sections=change.sections {
                guard project.recipe.pasting(expected,sections:sections)==project.recipe else {
                    throw NSError(domain:"PoolHistory",code:1,userInfo:[NSLocalizedDescriptionKey:"A synced item has changed outside this undo history. Use its saved version to restore safely."])
                }
                updated.recipe=project.recipe.pasting(target,sections:sections)
            } else {updated.recipe=target}
            updated.modified=Date();originals.append(project);updates.append(updated)
        }
        var saved=[Project]()
        do {for update in updates {saved.append(try save(update))};return saved}
        catch {for original in originals {try? save(original)};throw error}
    }
}
@MainActor extension EditingPool {
    func recordEdit(id:UUID,before:Recipe,after:Recipe) {
        guard before != after else {return}
        record(PoolHistoryStep(title:"Edit",changes:[PoolHistoryChange(id:id,before:before,after:after)]))
    }
    func record(_ step:PoolHistoryStep) {
        guard !historyBusy,!step.changes.isEmpty else {return}
        undoHistory.append(step);if undoHistory.count>40 {undoHistory.removeFirst()};redoHistory=[];historyMessage=nil
    }
    func moveHistory(undo:Bool,library:StudioLibrary) async throws {
        guard let step=(undo ? undoHistory:redoHistory).last else {return}
        let projects=try await library.vault.applyPoolHistory(step,undo:undo)
        for project in projects {if let i=library.projects.firstIndex(where:{$0.id==project.id}) {library.projects[i]=project}}
        if undo {undoHistory.removeLast();redoHistory.append(step)} else {redoHistory.removeLast();undoHistory.append(step)}
        historyMessage="\(undo ? "Undid":"Redid") \(step.title.lowercased()) · \(step.changes.count) item\(step.changes.count==1 ? "":"s")"
    }
}
