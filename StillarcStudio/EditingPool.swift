import SwiftUI

struct EditingPoolState:Codable,Equatable,Sendable {
    var ids:[UUID]
    var active:UUID
    var selected:Set<UUID>
    var toolName:String? = nil
    func available(_ projects:[Project]) -> Self? {
        let valid=Set(projects.map(\.id));var seen=Set<UUID>()
        let ids=Array(ids.filter {valid.contains($0) && seen.insert($0).inserted}.prefix(20))
        guard let first=ids.first else {return nil}
        return Self(ids:ids,active:ids.contains(active) ? active:first,selected:selected.intersection(ids),toolName:toolName)
    }
}
@MainActor @Observable final class EditingPool:Identifiable {
    static let storageKey="studio.editingPool.state"
    let id=UUID()
    var state:EditingPoolState
    var selecting=false
    var collapsed=false
    var tool:Tool {get {Tool(rawValue:state.toolName ?? "Light") ?? .light} set {state.toolName=newValue.rawValue;save()}}
    init(_ state:EditingPoolState) {self.state=state;save()}
    convenience init?(projects:[Project]) {
        let ids=Array(projects.prefix(20).map(\.id))
        guard let first=ids.first else {return nil}
        self.init(EditingPoolState(ids:ids,active:first,selected:Set(ids)))
    }
    var index:Int {state.ids.firstIndex(of:state.active) ?? 0}
    func save() {if let data=try? JSONEncoder().encode(state) {UserDefaults.standard.set(data,forKey:Self.storageKey)}}
    func activate(_ id:UUID) {guard state.ids.contains(id) else {return};state.active=id;save()}
    func toggle(_ id:UUID) {guard state.ids.contains(id) else {return};if !state.selected.insert(id).inserted {state.selected.remove(id)};save()}
    func projects(_ library:StudioLibrary,selected:Bool=false) -> [Project] {
        let byID=Dictionary(library.projects.map {($0.id,$0)},uniquingKeysWith:{a,_ in a})
        return state.ids.filter {!selected || state.selected.contains($0)}.compactMap {byID[$0]}
    }
}
@MainActor struct EditingPoolEditor:View {
    @Bindable var pool:EditingPool
    @Bindable var library:StudioLibrary
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        if let project=library.projects.first(where:{$0.id==pool.state.active}) {
            PhotoEditor(project:project,library:library,pool:pool).id(project.id)
        } else {ContentUnavailableView {Label("Project unavailable",systemImage:"photo")} actions:{Button("Back to workspace"){dismiss()}}}
    }
}

extension Recipe {
    /// One inference, one shared matte/cache identity, two independently editable regions.
    mutating func addSubjectBackground(_ matte:AutomaticMask) throws -> UUID {
        guard masks.count<=2,matte.matches(self) else {throw AutomaticSelectionEngine.error("Subject & Background needs two free mask slots and an unchanged crop.")}
        var subject=LocalMask(kind:.subject);subject.region = .subject;subject.automatic=matte;subject.refinement=AutomaticRefinement()
        var background=LocalMask(kind:.subject);background.region = .background;background.automatic=matte;background.refinement=AutomaticRefinement();background.inverted=true
        masks += [subject,background];return subject.id
    }
}
enum MaskRegion:String,Codable,Sendable {case subject="Subject",background="Background"}
