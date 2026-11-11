import SwiftUI
import Photos
import UniformTypeIdentifiers

@MainActor struct PhotoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var session: EditSession
    @Bindable var library: StudioLibrary
    @State private var tool: Tool = .light
    @State private var comparing = false
    @State private var export = false
    @State private var presets = false
    @State private var reset = false
    @State private var diagnosticsRunning = false
    @State private var zoom = 1.0
    @GestureState private var pinch = 1.0
    @State private var offset = CGSize.zero
    @GestureState private var drag = CGSize.zero
    init(project: Project, library: StudioLibrary) { _session = State(initialValue: EditSession(project)); self.library = library }
    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                if geometry.size.width > 800 {
                    HStack(spacing: 0) {
                        preview
                        VStack(spacing: 0) { tools; controls }.frame(width: 340).background(StudioStyle.panel)
                    }
                } else {
                    VStack(spacing: 0) {
                        preview
                        tools
                        controls.frame(height: min(280,geometry.size.height * 0.43)).background(StudioStyle.panel)
                    }
                }
            }
        }
        .background(StudioStyle.ink).tint(StudioStyle.blue)
        .task {
            await session.open(library: library)
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let flag = arguments.firstIndex(of: "--tool"), arguments.count > flag + 1, let selected = Tool(rawValue: arguments[flag+1]) { tool = selected }
            #endif
            await runPreviewCheckIfRequested()
        }
        .onChange(of: session.recipe) { _, _ in if !diagnosticsRunning { session.scheduleSave(library) } }
        .onChange(of: phase) { _, phase in if phase != .active { Task { await session.persist(library) } } }
        .onDisappear { Task { await session.persist(library) } }
        .sheet(isPresented: $export) { ExportSheet(session: session) }
        .sheet(isPresented: $presets) { PresetsSheet(session: session,library: library) }
        .confirmationDialog("Reset all adjustments?",isPresented: $reset,titleVisibility: .visible) { Button("Reset photo",role: .destructive) { session.change { $0 = Recipe() } } } message: { Text("You can undo this. The original photograph is always preserved.") }
        .alert("Unable to complete",isPresented: Binding(get: { session.error != nil },set: { if !$0 { session.error = nil } })) { Button("OK") { session.error = nil } } message: { Text(session.error ?? "") }
    }
    private var header: some View {
        HStack(spacing: 8) {
            Button { Task { await session.persist(library); dismiss() } } label: { Image(systemName: "chevron.left").frame(width: 44,height: 44) }.accessibilityLabel("Back to workspace")
            VStack(alignment: .leading,spacing: 3) {
                Text(session.project.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(session.saved ? "ALL CHANGES SAVED" : "SAVING ADJUSTMENTS").font(.system(size: 8,weight: .medium,design: .monospaced)).tracking(1).foregroundStyle(StudioStyle.secondary)
            }
            Spacer(minLength: 0)
            Button { session.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 36,height: 44) }.disabled(session.undoStack.isEmpty).accessibilityLabel("Undo")
            Button { session.redo() } label: { Image(systemName: "arrow.uturn.forward").frame(width: 36,height: 44) }.disabled(session.redoStack.isEmpty).accessibilityLabel("Redo")
            Button { export = true } label: { Image(systemName: "square.and.arrow.up").frame(width: 44,height: 44).background(StudioStyle.blue.opacity(0.16),in: Circle()) }.disabled(session.source == nil).accessibilityLabel("Export photo")
        }.foregroundStyle(.white).padding(.horizontal,10).padding(.vertical,8)
    }
    private var preview: some View {
        GeometryReader { geometry in
            ZStack {
                StudioStyle.ink
                if let source = session.source {
                    LivePreview(source: source.image,recipe: session.recipe,original: comparing,active: phase == .active && !export && !presets)
                        .scaleEffect(zoom * pinch).offset(x: offset.width+drag.width,y: offset.height+drag.height)
                        .gesture(MagnifyGesture().updating($pinch) { value,state,_ in state = value.magnification }.onEnded { value in zoom = min(4,max(1,zoom * value.magnification)); if zoom == 1 { offset = .zero } })
                        .simultaneousGesture(DragGesture(minimumDistance: 8).updating($drag) { value,state,_ in if zoom > 1 { state = value.translation } }.onEnded { value in if zoom > 1 { offset.width += value.translation.width; offset.height += value.translation.height } })
                        .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.2)) { zoom = zoom > 1 ? 1 : 2; offset = .zero } }
                        .accessibilityLabel(comparing ? "Original photograph" : "Edited photograph")
                } else if session.busy { ProgressView("Preparing your photo…").font(.caption) }
                else { ContentUnavailableView("Could not open photo",systemImage: "photo.badge.exclamationmark",description: Text(session.error ?? "Return to the workspace and try another file.")) }
                VStack {
                    HStack {
                        Text(comparing ? "ORIGINAL" : (session.project.isRAW ? "RAW DEVELOP" : "LIVE PREVIEW"))
                            .font(.system(size: 9,weight: .semibold,design: .monospaced)).tracking(1).padding(.horizontal,10).padding(.vertical,7).background(.black.opacity(0.65),in: Capsule())
                        Spacer()
                        Text("\(session.project.width) × \(session.project.height)").font(.system(size: 9,design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    HStack {
                        Button { presets = true } label: { Label("Looks",systemImage: "square.stack").font(.caption.weight(.medium)).padding(.horizontal,13).padding(.vertical,10).background(.ultraThinMaterial,in: Capsule()) }.disabled(session.source == nil)
                        Spacer()
                        Text("Hold to compare").font(.caption).padding(.horizontal,13).padding(.vertical,10).background(.ultraThinMaterial,in: Capsule())
                            .onLongPressGesture(minimumDuration: .infinity,pressing: { comparing = $0 },perform: {})
                            .accessibilityAddTraits(.isButton).accessibilityAction { comparing.toggle() }
                    }
                }.padding(15)
            }.frame(width: geometry.size.width,height: geometry.size.height).clipped()
        }
    }
    private var tools: some View {
        HStack(spacing: 0) {
            ForEach(Tool.allCases) { item in
                Button { tool = item } label: {
                    VStack(spacing: 6) { Image(systemName: item.symbol).font(.system(size: 18)); Text(item.rawValue).font(.system(size: 10,weight: .medium)) }
                        .frame(maxWidth: .infinity).frame(height: 66).foregroundStyle(tool == item ? StudioStyle.blue : StudioStyle.secondary)
                        .background(alignment: .bottom) { if tool == item { Capsule().fill(StudioStyle.blue).frame(width: 24,height: 3) } }
                }.buttonStyle(.plain).accessibilityAddTraits(tool == item ? .isSelected : [])
            }
        }.background(StudioStyle.panel).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }
    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 22) {
                HStack(alignment: .top) {
                    Text(tool.help).font(.system(size: 11)).foregroundStyle(StudioStyle.secondary).lineSpacing(3).fixedSize(horizontal: false,vertical: true)
                    Spacer(minLength: 10)
                    Button { reset = true } label: { Image(systemName: "arrow.counterclockwise").frame(width: 30,height: 30) }.accessibilityLabel("Reset all adjustments")
                }
                switch tool {
                case .light:
                    adjustment("Exposure",key: \.exposure,range: -3...3,unit: "EV")
                    adjustment("Contrast",key: \.contrast)
                    adjustment("Highlights",key: \.highlights)
                    adjustment("Shadows",key: \.shadows)
                case .color:
                    adjustment("Warmth",key: \.warmth)
                    adjustment("Tint",key: \.tint)
                    adjustment("Saturation",key: \.saturation)
                    adjustment("Vibrance",key: \.vibrance)
                case .film:
                    ScrollView(.horizontal,showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(FilmLook.allCases,id: \.self) { look in
                                Button { session.change { $0.look = look } } label: {
                                    Text(look.rawValue).font(.caption.weight(.medium)).padding(.horizontal,14).padding(.vertical,11).background(session.recipe.look == look ? StudioStyle.blue : Color.white.opacity(0.05),in: Capsule()).foregroundStyle(.white)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text(session.recipe.look.subtitle).font(.caption).foregroundStyle(StudioStyle.secondary)
                    if session.recipe.look != .original { adjustment("Look strength",key: \.lookAmount,range: 0...1,defaultValue: 1) }
                    adjustment("Grain",key: \.grain,range: 0...1)
                    adjustment("Bloom",key: \.bloom,range: 0...1)
                    adjustment("Fade",key: \.fade,range: 0...1)
                    adjustment("Vignette",key: \.vignette,range: 0...1)
                case .curves:
                    CurveDiagram(recipe: session.recipe).frame(height: 100)
                    adjustment("Dark tones",key: \.curveShadows)
                    adjustment("Middle tones",key: \.curveMidtones)
                    adjustment("Bright tones",key: \.curveHighlights)
                case .detail:
                    adjustment("Sharpen",key: \.sharpen,range: 0...1)
                    adjustment("Noise reduction",key: \.noise,range: 0...1)
                    Text("For fine detail, export at full resolution. Pinch or double-tap the preview to inspect your composition.").font(.caption).foregroundStyle(StudioStyle.secondary)
                case .crop:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))],spacing: 10) {
                        ForEach(Crop.allCases,id: \.self) { crop in
                            Button { session.change { $0.crop = crop }; zoom = 1; offset = .zero } label: {
                                Text(crop.rawValue).font(.caption.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical,14).background(session.recipe.crop == crop ? StudioStyle.blue : Color.white.opacity(0.05),in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                            }.buttonStyle(.plain)
                        }
                    }
                    Button { session.change { $0.rotation = ($0.rotation + 1) % 4 }; zoom = 1; offset = .zero } label: { Label("Rotate 90°",systemImage: "rotate.right").font(.subheadline).frame(maxWidth: .infinity).padding(14).background(.white.opacity(0.05),in: RoundedRectangle(cornerRadius: 12)) }
                    Text("These are centered crops. Free positioning and perspective correction are coming in a later build.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
            }.padding(20).padding(.bottom,12)
        }.scrollIndicators(.hidden)
    }
    private func adjustment(_ name: String,key: WritableKeyPath<Recipe,Double>,range: ClosedRange<Double> = -1...1,unit: String = "",defaultValue: Double = 0) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(name).font(.system(size: 13,weight: .medium))
                Spacer()
                Text(unit == "EV" ? String(format: "%+.2f EV",session.recipe[keyPath: key]) : String(format: "%+.0f",session.recipe[keyPath: key] * 100))
                    .font(.system(size: 11,weight: .medium,design: .monospaced)).foregroundStyle(session.recipe[keyPath: key] == defaultValue ? StudioStyle.secondary : StudioStyle.blue)
            }
            Slider(value: Binding(get: { session.recipe[keyPath: key] },set: { session.recipe[keyPath: key] = $0 }),in: range,onEditingChanged: { editing in if editing { session.begin() } else { session.end() } })
                .accessibilityLabel(name)
        }.contentShape(Rectangle()).onTapGesture(count: 2) { session.change { $0[keyPath: key] = defaultValue } }
    }
    private func runPreviewCheckIfRequested() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--verify-preview"), session.source != nil else { return }
        diagnosticsRunning = true
        let initialRecipe = session.recipe
        defer { session.recipe = initialRecipe; diagnosticsRunning = false }
        try? await Task.sleep(for: .seconds(1))
        PreviewMetrics.shared.times = []; PreviewMetrics.shared.failures = 0
        let start = ProcessInfo.processInfo.thermalState.rawValue
        session.recipe.look = .daylight; session.recipe.grain = 0.15; session.recipe.bloom = 0.1
        let steps = ProcessInfo.processInfo.arguments.contains("--sustained-preview") ? 7200 : 180
        for index in 0..<steps {
            session.recipe.exposure = sin(Double(index) * 0.13)
            session.recipe.warmth = cos(Double(index) * 0.11) * 0.4
            try? await Task.sleep(for: .milliseconds(16))
        }
        try? await Task.sleep(for: .seconds(1))
        let count = PreviewMetrics.shared.times.count
        try? await Task.sleep(for: .seconds(3))
        let times = PreviewMetrics.shared.times.sorted()
        let report: [String: Any] = ["requestedUpdates": steps,"rendered": count,"p95Milliseconds": times.isEmpty ? 0 : times[Int(Double(times.count-1)*0.95)],"extraIdleFrames": times.count-count,"gpuFailures": PreviewMetrics.shared.failures,"thermalStart": start,"thermalEnd": ProcessInfo.processInfo.thermalState.rawValue]
        if let data = try? JSONSerialization.data(withJSONObject: report,options: .prettyPrinted) {
            try? data.write(to: FileManager.default.urls(for: .documentDirectory,in: .userDomainMask)[0].appendingPathComponent("preview-verification.json"),options: .atomic)
        }
        #endif
    }
}
@MainActor struct CurveDiagram: View {
    let recipe: Recipe
    var body: some View {
        Canvas { context,size in
            var grid = Path()
            for n in 0...4 { let f = CGFloat(n)/4; grid.move(to: CGPoint(x: f*size.width,y: 0)); grid.addLine(to: CGPoint(x: f*size.width,y: size.height)); grid.move(to: CGPoint(x: 0,y: f*size.height)); grid.addLine(to: CGPoint(x: size.width,y: f*size.height)) }
            context.stroke(grid,with: .color(.white.opacity(0.08)),lineWidth: 1)
            let values = [recipe.fade * 0.15,0.25+recipe.curveShadows*0.15,0.5+recipe.curveMidtones*0.2,0.75+recipe.curveHighlights*0.15,1]
            var curve = Path(); curve.move(to: CGPoint(x: 0,y: size.height*(1-values[0])))
            for n in 1...4 { curve.addLine(to: CGPoint(x: CGFloat(n)/4*size.width,y: size.height*(1-values[n]))) }
            context.stroke(curve,with: .color(StudioStyle.blue),style: StrokeStyle(lineWidth: 2,lineCap: .round,lineJoin: .round))
        }.accessibilityLabel("Tone curve overview")
    }
}
