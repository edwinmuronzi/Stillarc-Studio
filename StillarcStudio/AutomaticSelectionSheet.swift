import SwiftUI

struct AutomaticSelectionTarget:Identifiable {
    let id = UUID()
    let kind:LocalMaskKind
    let maskID:UUID?
    var paired=false
}
struct AutomaticSelectionSheet:View {
    @Bindable var session:EditSession
    let target:AutomaticSelectionTarget
    let didSave:(UUID)->Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    private var background:Bool {session.recipe.masks.first(where:{$0.id==target.maskID})?.region == .background}
    private var selectionTitle:String {target.paired ? "Subject & Background" : (background ? "Background" : target.kind.rawValue)}
    @State private var image:CGImage?
    @State private var busy = false
    @State private var message:String?
    @State private var inputJob:Task<CGImage,Error>?
    @State private var job:Task<AutomaticMask,Error>?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    if let image { Image(decorative:image,scale:1).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:330).background(.black,in:RoundedRectangle(cornerRadius:16)) }
                    else if message == nil { ProgressView("Preparing analysis preview…").frame(maxWidth:.infinity).frame(height:240) }
                    Text(target.paired ? "Subject & Background" : (background ? "Select the background" : (target.kind == .subject ? "Select foreground subjects" : "Select the sky"))).font(.title2.weight(.semibold))
                    Text(target.kind == .subject ? "Finds foreground subjects and saves a soft selection. It can include more than one object. Review the red Guide, then adjust exposure, color or contrast just in that area." : "Finds likely sky and saves a soft selection, including cloudy sky where recognized. Review the red Guide; buildings, reflections or detailed clouds can confuse a small model. Refine the edge or combine it with a brush when needed.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    if background {Text("Detects the foreground once, then uses the inverse selection for the background. Existing background adjustments are preserved when recreating its selection.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    if target.paired { Text("One analysis creates two independently editable regions. Choose Subject or Background in Masks, then adjust its exposure, warmth, saturation and contrast. This edits the background; it does not remove it.").font(.subheadline).foregroundStyle(StudioStyle.secondary) }
                    if session.project.isVideo { Text("This analyzes the first kept frame once. It does not segment every video frame. A Subject mask can use position tracking afterward; changing poses or camera movement may need a new selection.").font(.subheadline).foregroundStyle(StudioStyle.secondary) }
                    if busy { HStack { ProgressView();Text("Analyzing on device…").font(.subheadline) } }
                    if let message { Text(message).font(.caption).foregroundStyle(StudioStyle.secondary) }
                    if image == nil && message != nil { Button("Reload preview") { Task { await load() } }.disabled(inputJob != nil) }
                    Button(action:analyze) { Label(target.paired ? "Create Subject & Background" : "Create \(target.kind.rawValue.lowercased()) mask",systemImage:target.kind == .subject ? "person.crop.rectangle" : "cloud.sun").frame(maxWidth:.infinity).padding(12) }.buttonStyle(.borderedProminent).disabled(image == nil || busy).accessibilityIdentifier("createAutomaticMask")
                    Text("Runs only when requested. No photos are uploaded. Results stay editable and save with this project. Canceling or leaving Studio keeps the previous masks unchanged. Automatic selections are estimates; fine hair, translucent edges, low contrast or night scenes may need a brush or range-mask refinement.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(20)
            }.navigationTitle("\(selectionTitle) selection").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(busy ? "Cancel analysis" : "Done") { inputJob?.cancel();job?.cancel();dismiss() } }
                .interactiveDismissDisabled(busy)
        }.tint(StudioStyle.blue).presentationDetents([.large])
            .task { await load() }
            .onDisappear { inputJob?.cancel();job?.cancel() }
            .onChange(of:phase) { _,value in if value != .active { inputJob?.cancel();job?.cancel();message = "Analysis canceled when Studio left the foreground. Your masks are unchanged." } }
    }
    @MainActor private func load() async {
        guard let url = session.sourceURL else { return }
        message = nil
        let recipe = session.recipe,video = session.project.video,prepared = session.source
        let task = Task.detached(priority:.userInitiated) { try await AutomaticSelectionEngine.input(url:url,video:video,recipe:recipe,prepared:prepared) };inputJob = task
        defer { inputJob = nil }
        do { let cg = try await task.value;guard !task.isCancelled,phase == .active else { return };image = cg }
        catch is CancellationError {}
        catch { message = error.localizedDescription }
    }
    @MainActor private func analyze() {
        guard let image else { return }
        let recipe = session.recipe,kind = target.kind,start = session.project.isVideo ? session.recipe.video.start : nil
        busy = true;message = nil
        let task = Task.detached(priority:.utility) { try await AutomaticSelectionEngine.analyze(image,kind:kind,recipe:recipe,videoStart:start) };job = task
        Task { @MainActor in
            defer { busy = false;job = nil }
            do {
                let stored = try await task.value
                guard !task.isCancelled,phase == .active,stored.matches(session.recipe) else { return }
                var id:UUID?
                if target.paired {
                    var updated = session.recipe
                    id = try updated.addSubjectBackground(stored)
                    session.change { $0 = updated }
                } else if let previous = target.maskID,let index = session.recipe.masks.firstIndex(where:{ $0.id == previous }) {
                    session.change { $0.masks[index].automatic = stored;$0.masks[index].motion = nil };id = previous
                } else if session.recipe.masks.count<4 {
                    var layer = LocalMask(kind:kind);layer.automatic = stored;layer.refinement = AutomaticRefinement()
                    session.change { $0.masks.append(layer) };id = layer.id
                }
                if let id { didSave(id) };dismiss()
            } catch is CancellationError { message = "Analysis canceled. Your masks are unchanged." }
            catch { message = error.localizedDescription }
        }
    }
}
