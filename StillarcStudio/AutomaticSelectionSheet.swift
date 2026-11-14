import SwiftUI

struct AutomaticSelectionTarget:Identifiable {
    let id = UUID()
    let kind:LocalMaskKind
    let maskID:UUID?
    var paired=false
    var removeBackground=false
}
struct AutomaticSelectionSheet:View {
    @Bindable var session:EditSession
    let target:AutomaticSelectionTarget
    let didSave:(UUID)->Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    private var background:Bool {session.recipe.masks.first(where:{$0.id==target.maskID})?.region == .background}
    private var selectionTitle:String {target.removeBackground ? "Remove background" : (target.paired ? "Subject & Background" : (background ? "Background" : target.kind.rawValue))}
    @State private var subjectMode=SubjectSelectionMode.foreground
    @State private var pickedSubjects=[CGPoint]()
    @State private var picked:CGPoint?
    @State private var image:CGImage?
    @State private var busy = false
    @State private var message:String?
    @State private var inputJob:Task<CGImage,Error>?
    @State private var job:Task<AutomaticMask,Error>?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    if let image {
                        GeometryReader {g in
                            let fit=MaskViewport().rect(size:CGSize(width:image.width,height:image.height),container:g.size)
                            Image(decorative:image,scale:1).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity)
                            if subjectMode == .picked || subjectMode == .multiple {
                                Color.clear.contentShape(Rectangle()).gesture(SpatialTapGesture().onEnded {v in if !busy,fit.contains(v.location) {
                                    let p=CGPoint(x:(v.location.x-fit.minX)/fit.width,y:(v.location.y-fit.minY)/fit.height)
                                    if subjectMode == .multiple {if let i=pickedSubjects.firstIndex(where:{hypot(($0.x-p.x)*fit.width,($0.y-p.y)*fit.height)<24}) {pickedSubjects.remove(at:i)} else if pickedSubjects.count<8 {pickedSubjects.append(p)}} else {picked=p}
                                }}).accessibilityLabel("Tap inside the subject to select").accessibilityIdentifier("subjectPickPreview")
                                ForEach(Array(pickedSubjects.enumerated()),id:\.offset){_,p in if subjectMode == .multiple {Image(systemName:"scope").font(.title).foregroundStyle(StudioStyle.blue).position(x:fit.minX+p.x*fit.width,y:fit.minY+p.y*fit.height).allowsHitTesting(false)}}
                                if let picked,subjectMode == .picked {Image(systemName:"scope").font(.title).foregroundStyle(.white).shadow(radius:3).position(x:fit.minX+picked.x*fit.width,y:fit.minY+picked.y*fit.height).allowsHitTesting(false)}
                            }
                        }.frame(height:300).background(.black,in:RoundedRectangle(cornerRadius:16))
                    }
                    else if message == nil { ProgressView("Preparing analysis preview…").frame(maxWidth:.infinity).frame(height:240) }
                    if target.kind == .subject {
                        Picker("Selection method",selection:$subjectMode){ForEach(SubjectSelectionMode.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.menu).disabled(busy).accessibilityIdentifier("subjectSelectionMethod")
                        if subjectMode == .multiple {HStack {Text("\(pickedSubjects.count)/8 subject taps");Spacer();Button("Clear taps"){pickedSubjects=[]}.disabled(busy)}.font(.caption)}
                        Text(subjectMode.help).font(.caption).foregroundStyle(StudioStyle.secondary)
                    }
                    Text(target.paired ? "Subject & Background" : (background ? "Select the background" : (target.kind == .subject ? "Select foreground subjects" : "Select the sky"))).font(.title2.weight(.semibold))
                    Text(target.kind == .subject ? "Finds foreground subjects and saves a soft selection. It can include more than one object. Review the red Guide, then adjust exposure, color or contrast just in that area." : "Finds likely sky and saves a soft selection, including cloudy sky where recognized. Review the red Guide; buildings, reflections or detailed clouds can confuse a small model. Refine the edge or combine it with a brush when needed.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    if background {Text("Detects the foreground once, then uses the inverse selection for the background. Existing background adjustments are preserved when recreating its selection.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    if target.paired { Text("One analysis creates two independently editable regions. Choose Subject or Background in Masks, then adjust its exposure, warmth, saturation and contrast. This edits the background; it does not remove it.").font(.subheadline).foregroundStyle(StudioStyle.secondary) }
                    if session.project.isVideo { Text("This analyzes the first kept frame once. It does not segment every video frame. A Subject mask can use position tracking afterward. For changing outlines, use Masks → Add mask → Object video matte or People video matte instead.").font(.subheadline).foregroundStyle(StudioStyle.secondary) }
                    if busy { HStack { ProgressView();Text("Analyzing on device…").font(.subheadline) } }
                    if let message { Text(message).font(.caption).foregroundStyle(StudioStyle.secondary) }
                    if image == nil && message != nil { Button("Reload preview") { Task { await load() } }.disabled(inputJob != nil) }
                    Button(action:analyze) { Label(target.removeBackground ? "Remove background" : (target.paired ? "Create Subject & Background" : "Create \(target.kind.rawValue.lowercased()) mask"),systemImage:target.kind == .subject ? "person.crop.rectangle" : "cloud.sun").frame(maxWidth:.infinity).padding(12) }.buttonStyle(.borderedProminent).disabled(image == nil || busy || (target.kind == .subject && ((subjectMode == .picked && picked == nil) || (subjectMode == .multiple && pickedSubjects.isEmpty)))).accessibilityIdentifier("createAutomaticMask")
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
        if let previous=session.recipe.masks.first(where:{$0.id==target.maskID})?.automatic?.selectionMode {subjectMode=previous}
        let recipe = session.recipe,video = session.project.video,prepared = session.source
        let task = Task.detached(priority:.userInitiated) { try await AutomaticSelectionEngine.input(url:url,video:video,recipe:recipe,prepared:prepared) };inputJob = task
        defer { inputJob = nil }
        do { let cg = try await task.value;guard !task.isCancelled,phase == .active else { return };image = cg }
        catch is CancellationError {}
        catch { message = error.localizedDescription }
    }
    @MainActor private func analyze() {
        guard let image else { return }
        let mode=subjectMode,point=picked,points=pickedSubjects
        let recipe = session.recipe,kind = target.kind,start = session.project.isVideo ? session.recipe.video.start : nil
        busy = true;message = nil
        let task = Task.detached(priority:.utility) { try await AutomaticSelectionEngine.analyze(image,kind:kind,recipe:recipe,videoStart:start,subjectMode:mode,point:point,points:points) };job = task
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
                    session.change { $0.masks[index].automatic = stored;$0.masks[index].motion = nil;$0.masks[index].label=(mode == .faces || mode == .skin) ? mode.rawValue:nil };id = previous
                } else if session.recipe.masks.count<4 {
                    var layer = LocalMask(kind:kind);layer.label=(mode == .faces || mode == .skin) ? mode.rawValue:nil;layer.automatic = stored;layer.refinement = AutomaticRefinement();layer.cutout=target.removeBackground ? true:nil
                    session.change { if target.removeBackground {for i in $0.masks.indices {$0.masks[i].cutout=nil}};$0.masks.append(layer) };id = layer.id
                }
                if let id { didSave(id) };dismiss()
            } catch is CancellationError { message = "Analysis canceled. Your masks are unchanged." }
            catch { message = error.localizedDescription }
        }
    }
}
