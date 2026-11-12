import SwiftUI

struct MaskTrackingSheet:View {
    @Bindable var session:EditSession
    let maskID:UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var quality=TrackingQuality.detailed
    @State private var seed = TrackingSeed()
    @State private var poster:CGImage?
    @State private var busy = false
    @State private var progress = 0.0
    @State private var message:String?
    @State private var job:Task<MaskMotion,Error>?
    @State private var initialSeed = TrackingSeed()
    private var canAnalyze:Bool { poster != nil && !busy && session.sourceURL != nil }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    if let poster {
                        GeometryReader { geometry in
                            let scale = min(geometry.size.width/Double(poster.width),geometry.size.height/Double(poster.height))
                            let w = Double(poster.width)*scale,h = Double(poster.height)*scale,l = (geometry.size.width-w)/2,t = (geometry.size.height-h)/2
                            Image(decorative:poster,scale:1).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity)
                            RoundedRectangle(cornerRadius:8).stroke(StudioStyle.blue,lineWidth:2).background(StudioStyle.blue.opacity(0.08))
                                .frame(width:w*seed.width,height:h*seed.height).position(x:l+w*seed.rect.midX,y:t+h*(1-seed.rect.midY))
                                .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("trackingFrame")).onChanged { value in
                                    guard !busy else { return };seed.x = min(1,max(0,(value.location.x-l)/w));seed.y = min(1,max(0,(value.location.y-t)/h))
                                }).accessibilityLabel("Tracking target; use position and size sliders below")
                        }.frame(height:240).coordinateSpace(name:"trackingFrame").accessibilityElement(children:.contain).accessibilityIdentifier("trackingFrame").background(.black,in:RoundedRectangle(cornerRadius:16))
                    } else { ProgressView("Loading first kept frame…").frame(maxWidth:.infinity).frame(height:240) }
                    Text("Choose a textured target on the first kept frame").font(.headline)
                    Text("Drag the blue box over the object, then size it to include useful detail. This ungraded preview chooses what to follow; it does not redraw your mask. Your mask moves by the target’s displacement.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
                    seedSlider("Target horizontal position",key:\.x,range:0...1)
                    seedSlider("Target vertical position",key:\.y,range:0...1)
                    seedSlider("Target width",key:\.width,range:0.08...0.7)
                    seedSlider("Target height",key:\.height,range:0.08...0.7)
                    Picker("Tracking quality",selection:$quality){ForEach(TrackingQuality.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented).disabled(busy)
                    Text("Detailed uses a more accurate position tracker. Efficient favors faster analysis. Both analyze reduced-size frames once, then reuse the saved path during playback. Fine-tune drift afterward with Correct tracking.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    if busy { ProgressView(value:progress);Text("Analyzing motion… \(Int(progress*100))%").font(.caption.monospacedDigit()) }
                    if let message { Text(message).font(.caption).foregroundStyle(StudioStyle.secondary) }
                    Button(action:analyze) { Label("Analyze & save tracking",systemImage:"viewfinder").frame(maxWidth:.infinity).padding(12) }.buttonStyle(.borderedProminent).disabled(!canAnalyze).accessibilityIdentifier("trackingAnalyze")
                    Text("Tracks position only, forward across the kept clip (up to 2 minutes). Analysis uses up to 15 reduced-size frames per second; playback/export interpolate the saved motion at each frame’s timestamp. It stops if the target is lost or the phone needs cooling. No background tracking, shape deformation, scale or rotation tracking. Crop changes or extending the trim require a new track. Review the whole clip before exporting.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(20)
            }.navigationTitle("Track mask").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(busy ? "Cancel analysis" : "Done") { job?.cancel();dismiss() } }
                .interactiveDismissDisabled(busy)
        }.tint(StudioStyle.blue).presentationDetents([.large])
            .task { await load() }
            .onDisappear { job?.cancel() }
            .onChange(of:phase) { _,value in if value != .active { job?.cancel();message = "Analysis canceled when Studio left the foreground. Your previous track is unchanged." } }
    }
    private func seedSlider(_ title:String,key:WritableKeyPath<TrackingSeed,Double>,range:ClosedRange<Double>) -> some View {
        VStack { HStack { Text(title);Spacer();Text(seed[keyPath:key],format:.percent.precision(.fractionLength(0))) }.font(.caption)
            Slider(value:Binding(get:{ seed[keyPath:key] },set:{ seed[keyPath:key] = $0 }),in:range).accessibilityLabel(title).disabled(busy || poster == nil).sliderReset { if !busy && poster != nil { seed[keyPath:key] = initialSeed[keyPath:key] } }
        }
    }
    @MainActor private func load() async {
        guard let url = session.sourceURL,let descriptor = session.project.video,let mask = session.recipe.masks.first(where:{ $0.id == maskID }) else { return }
        if mask.kind == .brush,let points = mask.brush?.strokes.filter({ !$0.erase }).flatMap(\.points),!points.isEmpty {
            let xs = points.map(\.x),ys = points.map(\.y)
            seed.x = ((xs.min() ?? 0.3)+(xs.max() ?? 0.7))/2;seed.y = ((ys.min() ?? 0.3)+(ys.max() ?? 0.7))/2
        } else { seed.x = mask.centerX;seed.y = mask.centerY }
        let recipe = session.recipe
        do {
            let result=try await Task.detached(priority:.userInitiated) { (try await MaskTracker.seedFrame(url:url,descriptor:descriptor,recipe:recipe),mask.kind == .subject ? mask.automatic.flatMap {MaskTracker.suggestedSeed($0)}:nil) }.value
            poster=result.0;if let suggested=result.1 {seed=suggested};initialSeed=seed
        }
        catch { message = error.localizedDescription }
    }
    @MainActor private func analyze() {
        guard let url = session.sourceURL,let descriptor = session.project.video else { return }
        let recipe = session.recipe,target = seed,mode=quality
        busy = true;progress = 0;message = nil
        let task = Task.detached(priority:.utility) { try await MaskTracker.analyze(url:url,descriptor:descriptor,recipe:recipe,seed:target,quality:mode) { amount in await MainActor.run { progress = amount } } }
        job = task
        Task { @MainActor in
            defer { busy = false;job = nil }
            do {
                let track = try await task.value
                guard !task.isCancelled,phase == .active,MaskMotion.signature(session.recipe) == track.framing,let index = session.recipe.masks.firstIndex(where:{ $0.id == maskID }) else { return }
                session.change { $0.masks[index].motion = track };dismiss()
            } catch is CancellationError { message = "Analysis canceled. Your previous track is unchanged." }
            catch { message = error.localizedDescription }
        }
    }
}
