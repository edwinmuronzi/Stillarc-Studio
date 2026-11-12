import SwiftUI

extension ProjectVault {
    func pasteCopiedAdjustments(_ id:UUID,clipboard:AdjustmentClipboard,sections:Set<AdjustmentSection>) throws -> Project {
        let url = root.appendingPathComponent(id.uuidString+".json")
        var project = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
        let chosen = sections.intersection(clipboard.sections)
        guard !chosen.isEmpty else { return project }
        let recipe = project.recipe.pasting(clipboard.recipe,sections:chosen)
        guard recipe != project.recipe else { return project }
        guard (project.versions ?? []).count<20 else { throw NSError(domain:"BatchPaste",code:1,userInfo:[NSLocalizedDescriptionKey:"This project already has 20 versions. Remove a version before batch pasting."]) }
        let version = EditVersion(name:"Before batch paste")
        try saveVersion(project,version:version,recipe:project.recipe)
        project.versions = (project.versions ?? [])+[version];project.recipe = recipe;project.modified = Date()
        do { return try save(project) }
        catch { try? removeVersion(project,version:version);throw error }
    }
}
struct BatchPasteSheet:View {
    @Bindable var library:StudioLibrary
    let projects:[Project]
    let clipboard:AdjustmentClipboard
    var pool:EditingPool? = nil
    @State private var entirePool=false
    private var targets:[Project] {if let pool {return pool.projects(library,selected: !entirePool)};return projects}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var sections = Set<AdjustmentSection>()
    @State private var busy = false
    @State private var task:Task<Void,Never>?
    @State private var status:String?
    @State private var finished = false
    var body:some View {
        NavigationStack {
            List {
                if let pool {
                    Section("Apply current edits to") {
                        Picker("Pool scope",selection:$entirePool) {Text("Selected (\(pool.state.selected.count))").tag(false);Text("Entire pool (\(pool.state.ids.count))").tag(true)}.pickerStyle(.segmented)
                        Text("Choose the sections below. Crops, masks, input conversion and clip settings stay individual. Review each item afterward; syncing replaces only the chosen adjustment sections.").font(.caption)
                    }.disabled(busy || finished)
                }
                Section {
                    Text("Apply copied adjustments from \(clipboard.sourceName) to \(targets.count) selected projects. Each keeps its crop, input conversion, masks, trim and audio. A ‘Before batch paste’ version preserves each changed project's previous edit under Looks → Versions.").font(.subheadline)
                }
                Section("Adjustments to apply") {
                    ForEach(clipboard.sections) { section in
                        Toggle(isOn:Binding(get:{ sections.contains(section) },set:{ if $0 { sections.insert(section) } else { sections.remove(section) } })) { VStack(alignment:.leading) { Text(section.title);Text(section.help).font(.caption).foregroundStyle(StudioStyle.secondary) } }
                    }
                }.disabled(busy || finished)
            }.navigationTitle(pool == nil ? "Paste adjustments" : "Sync pool edits").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(busy) }
                .safeAreaInset(edge:.bottom) {
                    VStack(spacing:10) {
                        if busy { HStack { ProgressView();Button("Cancel remaining") { task?.cancel() } } }
                        else if !finished { Button(pool != nil && entirePool ? "Apply to entire pool" : "Apply to selected") { apply() }.disabled(sections.isEmpty || targets.isEmpty).buttonStyle(.borderedProminent).accessibilityIdentifier("applyBatchPaste") }
                        if let status { Text(status).font(.caption).lineLimit(4) }
                    }.frame(maxWidth:.infinity).padding(14).background(.regularMaterial)
                }
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .onAppear { sections = Set(clipboard.sections) }
        .onChange(of:phase) { _,value in if value != .active { task?.cancel() } }
        .onDisappear { task?.cancel() }
    }
    private func apply() {
        let projects = targets
        busy = true
        task = Task { @MainActor in
            defer { busy = false;finished = true;task = nil }
            var count = 0,failures:[String] = []
            for project in projects {
                if Task.isCancelled { break }
                while ProcessInfo.processInfo.thermalState.rawValue>=ProcessInfo.ThermalState.serious.rawValue && !Task.isCancelled { status = "Waiting for the phone to cool…";try? await Task.sleep(for:.seconds(1)) }
                if Task.isCancelled { break }
                status = "Applying \(count+failures.count+1) of \(projects.count)…"
                do {
                    let updated = try await library.vault.pasteCopiedAdjustments(project.id,clipboard:clipboard,sections:sections)
                    if let index = library.projects.firstIndex(where:{ $0.id == updated.id }) { library.projects[index] = updated };count += 1
                } catch { failures.append(project.name+": "+error.localizedDescription) }
            }
            status = "Applied to \(count) of \(projects.count)."+(Task.isCancelled ? " Remaining projects cancelled." : "")+(failures.isEmpty ? "" : " \(failures.count) failed: \(failures.first!)")
        }
    }
}
