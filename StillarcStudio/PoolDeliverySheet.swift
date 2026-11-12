import SwiftUI

struct PoolDeliverySheet:View {
    @Bindable var pool:EditingPool
    @Bindable var library:StudioLibrary
    @Bindable var session:EditSession
    @Environment(\.dismiss) private var dismiss
    @State private var chosen=Set<UUID>()
    @State private var exporting=false
    @State private var saved=false
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Button("Export all \(pool.state.ids.count) items") {chosen=Set(pool.state.ids);exporting=true}.disabled(!saved).accessibilityIdentifier("exportEntirePool")
                    Button("Select all") {chosen=Set(pool.state.ids)}
                    Button("Clear selection") {chosen=[]}
                }
                Section("Items to export") {
                    ForEach(pool.projects(library)) {project in
                        Button {if !chosen.insert(project.id).inserted {chosen.remove(project.id)}} label:{HStack {ProjectThumbnail(project:project,vault:library.vault,maxDimension:160).frame(width:40,height:44).clipShape(RoundedRectangle(cornerRadius:8));Text(project.name).foregroundStyle(.primary);Spacer();Image(systemName:chosen.contains(project.id) ? "checkmark.circle.fill":"circle")}}.accessibilityLabel("Export item \(project.name)").accessibilityValue(chosen.contains(project.id) ? "Selected":"Not selected")
                    }
                }
            }.navigationTitle("Pool delivery").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}
                .safeAreaInset(edge:.bottom) {Button("Export selected (\(chosen.count))"){exporting=true}.buttonStyle(.borderedProminent).disabled(chosen.isEmpty || !saved).padding(16).accessibilityIdentifier("exportChosenPoolItems")}
        }.tint(StudioStyle.blue)
        .task {chosen=pool.state.selected;session.pauseAutosave();saved=await session.persist(library)}
        .sheet(isPresented:$exporting) {BatchExportSheet(projects:pool.projects(library).filter {chosen.contains($0.id)},vault:library.vault)}
    }
}
