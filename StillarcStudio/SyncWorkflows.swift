import Foundation

struct SyncWorkflow:Identifiable,Codable,Equatable {
    var id=UUID()
    var name:String
    var sections:[AdjustmentSection]
}
enum SyncWorkflows {
    static let key="studio.sync.workflows"
    static func load(_ defaults:UserDefaults = .standard)->[SyncWorkflow] {
        guard let data=defaults.data(forKey:key),data.count<32_768,let items=try? JSONDecoder().decode([SyncWorkflow].self,from:data),items.count<=12,Set(items.map(\.id)).count==items.count else {return []}
        return items.filter {!$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.name.count<=80 && !$0.sections.isEmpty && Set($0.sections).count==$0.sections.count}
    }
    static func save(_ items:[SyncWorkflow],_ defaults:UserDefaults = .standard) throws {
        guard items.count<=12,Set(items.map(\.id)).count==items.count,items.allSatisfy({!$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.name.count<=80 && !$0.sections.isEmpty}) else {throw AutomaticSelectionEngine.error("Name a workflow and choose at least one section. Up to 12 workflows are supported.")}
        let data=try JSONEncoder().encode(items);guard data.count<32_768 else {throw StudioError.render};defaults.set(data,forKey:key)
    }
}
