import SwiftUI
import Photos
import UniformTypeIdentifiers

@MainActor struct PhotoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var session: EditSession
    @Bindable var library: StudioLibrary
    @State private var scopesVisible = false
    @State private var scopeMode = ScopeMode.histogram
    @State private var scopeSampler = ScopeSampler()
    @State private var tool: Tool = .light
    @State private var colorPanel: ColorPanel = .global
    @State private var wheelZone: WheelZone = .shadows
    @State private var mixerChannel: MixerChannel = .red
    @State private var selectedRange: ColorRange = .orange
    @State private var showRange = false
    @State private var curveChannel: CurveChannel = .master
    @State private var curvePoint: CurvePoint = .middle
    @State private var comparing = false
    @State private var export = false
    @State private var presets = false
    @State private var inputSheet = false
    @State private var trimSheet = false
    @State private var reset = false
    @State private var numericEdit: NumericEdit?
    @State private var numericText = ""
    @State private var cropDragStart: CGSize?
    @State private var diagnosticsRunning = false
    @State private var zoom = 1.0
    @GestureState private var pinch = 1.0
    @State private var offset = CGSize.zero
    @GestureState private var drag = CGSize.zero
    init(project: Project, library: StudioLibrary) { _session = State(initialValue: EditSession(project)); self.library = library }
    var body: some View {
        EditorSafeArea { VStack(spacing: 0) {
            header.background {
                #if DEBUG
                EditorLayoutVerification().allowsHitTesting(false)
                #endif
            }
            GeometryReader { geometry in
                if geometry.size.width > 800 {
                    HStack(spacing: 0) {
                        preview
                        VStack(spacing: 0) { scopePanel;tools; controls }.frame(width: 340).background(StudioStyle.panel)
                    }
                } else {
                    VStack(spacing: 0) {
                        preview
                        scopePanel
                        tools
                        controls.frame(height: min((tool == .curves || (tool == .color && colorPanel != .global)) ? 360 : 280,geometry.size.height * ((tool == .curves || (tool == .color && colorPanel != .global)) ? 0.54 : 0.43))).background(StudioStyle.panel)
                    }
                }
            }
        }
        }.background(StudioStyle.ink).tint(StudioStyle.blue)
        .task {
            await session.open(library: library)
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--scopes") { scopesVisible = true;scopeSampler.setEnabled(true) }
            if arguments.contains("--verify-trim-ui") { await verifyTrimUI() }
            if arguments.contains("--show-lut-example") { session.change { $0.lut = try? LUTVerification.example(dimension:33) }; tool = .film }
            if arguments.contains("--wheels") { colorPanel = .wheels }
            if arguments.contains("--mixer") { colorPanel = .mixer }
            if arguments.contains("--show-grading-example") {
                session.change { $0 = Recipe(); $0.colorWheels.shadows.hue = 220; $0.colorWheels.shadows.strength = 0.22; $0.colorWheels.highlights.hue = 40; $0.colorWheels.highlights.strength = 0.15; $0.channelMixer.redGreen = 0.03 }
            }
            if arguments.contains("--color-mix") { colorPanel = .selective }
            if arguments.contains("--range-preview") { showRange = true }
            if arguments.contains("--show-color-example") {
                session.change { $0 = Recipe(); $0.rgbCurves.master.shadows = 0.22; $0.rgbCurves.red.middle = 0.53; $0.rgbCurves.blue.shadows = 0.28; $0.selectiveColors.blue.saturation = -0.2; $0.selectiveColors.orange.brightness = 0.1 }
            }
            if arguments.contains("--show-adjusted-example") {
                session.change { $0.exposure = 0.25; $0.warmth = 0.12; $0.grain = 0.1; $0.crop = .portrait; $0.straighten = 3 }
            }
            if let flag = arguments.firstIndex(of: "--tool"), arguments.count > flag + 1, let selected = Tool(rawValue: arguments[flag+1]) { tool = selected }
            #endif
            await runPreviewCheckIfRequested()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-editor-layout") {
                for _ in 0..<4 { export = true;try? await Task.sleep(for:.milliseconds(400));export = false;try? await Task.sleep(for:.milliseconds(400)) }
            }
            #endif
        }
        .onChange(of:scopesActive) { _,value in scopeSampler.setEnabled(value) }
        .onDisappear { scopeSampler.setEnabled(false) }
        .onChange(of: session.recipe) { _, _ in if !diagnosticsRunning { session.scheduleSave(library) } }
        .onChange(of: phase) { _, phase in if phase != .active { Task { await session.persist(library) } } }
        .onDisappear { Task { await session.persist(library) } }
        .sheet(isPresented: $export) { ExportSheet(session: session) }
        .sheet(isPresented: $presets) { PresetsSheet(session: session,library: library) }
        .sheet(isPresented:$trimSheet) { VideoTrimSheet(session:session) }
        .sheet(isPresented:$inputSheet) { InputConversionSheet(session:session) }
        .confirmationDialog("Reset all adjustments?",isPresented: $reset,titleVisibility: .visible) { Button("Reset adjustments",role: .destructive) { session.change { $0 = Recipe() } } } message: { Text("You can undo this. The original is always preserved.") }
        .alert(numericEdit.map { "Set \($0.name.lowercased())" } ?? "Set value",isPresented: Binding(get: { numericEdit != nil },set: { if !$0 { numericEdit = nil } })) {
            TextField("Value",text: $numericText).keyboardType(.numbersAndPunctuation)
            Button("Cancel",role: .cancel) { numericEdit = nil }
            Button("Apply") {
                if let edit = numericEdit, let value = edit.parse(numericText) { session.change { $0[keyPath: edit.key] = value } }
                numericEdit = nil
            }.disabled(numericEdit?.parse(numericText) == nil)
        } message: {
            if let edit = numericEdit { Text("Enter a value from \(edit.displayRange.lowerBound.formatted()) to \(edit.displayRange.upperBound.formatted())\(edit.unit.isEmpty ? "" : " " + edit.unit).") }
        }
        .alert("Unable to complete",isPresented: Binding(get: { session.error != nil },set: { if !$0 { session.error = nil } })) { Button("OK") { session.error = nil } } message: { Text(session.error ?? "") }
    }
    #if DEBUG
    private func verifyTrimUI() async {
        guard session.project.isVideo else { return }
        let original = session.recipe
        let oldIdle = UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled = true
        diagnosticsRunning = true
        defer { session.recipe = original;diagnosticsRunning = false;UIApplication.shared.isIdleTimerDisabled = oldIdle }
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("trim-ui-verification.json")
        func report(_ value:[String:Any]) { if let data = try? JSONSerialization.data(withJSONObject:value,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) } }
        let playersBefore = VideoPlayback.creationCount,presentationsBefore = VideoTrimSheet.presentationCount
        var delays = [Double]()
        for cycle in 0..<5 {
            report(["passed":false,"stage":"opening trim","cycle":cycle])
            trimSheet = true
            for step in 0..<90 {
                let began = CACurrentMediaTime()
                try? await Task.sleep(for:.milliseconds(16))
                delays.append(CACurrentMediaTime()-began)
                if step == 30 { session.recipe.video.start = (session.project.video?.duration ?? 1)*0.1;session.recipe.video.end = (session.project.video?.duration ?? 1)*0.8 }
                if step == 60 { session.recipe.video = original.video }
            }
            trimSheet = false
            try? await Task.sleep(for:.milliseconds(300))
        }
        let players = VideoPlayback.creationCount-playersBefore,presentations = VideoTrimSheet.presentationCount-presentationsBefore
        report(["passed":presentations == 5 && players <= 6 && (delays.max() ?? 99)<1,"version":"0.7.1","playersCreated":players,"sheetsPresented":presentations,"stage":"complete","cycles":5,"heartbeatSamples":delays.count,"maxMainActorDelaySeconds":delays.max() ?? 0,"p95MainActorDelaySeconds":delays.sorted()[Int(Double(delays.count-1)*0.95)]])
    }
    #endif
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
            Button { export = true } label: { Image(systemName: "square.and.arrow.up").frame(width: 44,height: 44).background(StudioStyle.blue.opacity(0.16),in: Circle()) }.disabled(session.source == nil).accessibilityLabel(session.project.isVideo ? "Export video" : "Export photo")
        }.foregroundStyle(.white).padding(.horizontal,10).padding(.vertical,8)
    }
    private var preview: some View {
        GeometryReader { geometry in
            ZStack {
                StudioStyle.ink
                if let source = session.source {
                    Group {
                        if let video = session.project.video,let url = session.sourceURL {
                            VideoPreview(url:url,descriptor:video,poster:source,recipe:session.recipe,original:comparing,active:phase == .active && !export && !presets && !trimSheet,onTrim:{ trimSheet = true },scopes:scopesActive ? scopeSampler : nil,rangePreview:tool == .color && colorPanel == .selective && showRange ? selectedRange : nil)
                        } else {
                            LivePreview(source:source.image,recipe:session.recipe,signalSource:source.signalImage,original:comparing,rangePreview:tool == .color && colorPanel == .selective && showRange ? selectedRange : nil,active:phase == .active && !export && !presets,scopes:scopesActive ? scopeSampler : nil)
                        }
                    }
                        .scaleEffect(zoom * pinch).offset(x: offset.width+drag.width,y: offset.height+drag.height)
                        .gesture(MagnifyGesture().updating($pinch) { value,state,_ in state = value.magnification }.onEnded { value in zoom = min(4,max(1,zoom * value.magnification)); if zoom == 1 { offset = .zero } })
                        .simultaneousGesture(DragGesture(minimumDistance: 4).updating($drag) { value,state,_ in if zoom > 1 { state = value.translation } }.onChanged { value in
                            if tool == .crop && zoom == 1 && pinch == 1 && session.recipe.crop != .original { moveCrop(value,previewSize: geometry.size) }
                        }.onEnded { value in
                            if cropDragStart != nil { cropDragStart = nil; session.end() }
                            else if zoom > 1 { offset.width += value.translation.width; offset.height += value.translation.height }
                        })
                        .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.2)) { zoom = zoom > 1 ? 1 : 2; offset = .zero } }
                        .accessibilityLabel(comparing ? "Original photograph" : "Edited photograph")
                } else if session.busy { ProgressView("Preparing your media…").font(.caption) }
                else { ContentUnavailableView("Could not open media",systemImage: "photo.badge.exclamationmark",description: Text(session.error ?? "Return to the workspace and try another file.")) }
                if tool == .crop && zoom == 1 && pinch == 1, let source = session.source {
                    FramingGrid(sourceSize: source.image.extent.size,recipe: session.recipe).allowsHitTesting(false)
                }
                VStack {
                    HStack {
                        Button { inputSheet = true } label: {
                            Text(comparing ? "ORIGINAL" : (session.project.isRAW ? "RAW DEVELOP" : (session.recipe.input.profile == .standard ? (session.recipe.video.hdr ? "INPUT · HDR" : "INPUT · STANDARD") : session.recipe.input.profile.shortTitle+(session.recipe.video.hdr ? " → HDR" : " → SDR"))))
                                .font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1).padding(.horizontal,10).padding(.vertical,7).background(.black.opacity(0.65),in:Capsule())
                        }.disabled(session.project.isRAW).accessibilityLabel("Input conversion")
                        Spacer()
                        Button { scopesVisible.toggle() } label: { Label("Scopes",systemImage:"chart.bar.xaxis").foregroundStyle(scopesVisible ? Color.white : StudioStyle.blue).font(.caption2).padding(8).background(scopesVisible ? StudioStyle.blue : Color.black.opacity(0.65),in:Capsule()) }
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
    private var scopesActive:Bool { scopesVisible && phase == .active && !export && !presets && !trimSheet && !inputSheet }
    @ViewBuilder private var scopePanel:some View {
        if scopesVisible { ScopePanel(sampler:scopeSampler,mode:$scopeMode) }
    }
    private var tools: some View {
        HStack(spacing: 0) {
            ForEach(Tool.allCases) { item in
                Button { tool = item; if item == .crop { zoom = 1; offset = .zero } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 18))
                        Text(item.rawValue).font(.system(size: 10,weight: .medium))
                        Circle().fill(StudioStyle.blue).frame(width: 4,height: 4).opacity(session.recipe.hasAdjustments(in: item) ? 1 : 0).accessibilityHidden(true)
                    }
                        .frame(maxWidth: .infinity).frame(height: 74).foregroundStyle(tool == item ? StudioStyle.blue : StudioStyle.secondary)
                        .background(alignment: .bottom) { if tool == item { Capsule().fill(StudioStyle.blue).frame(width: 24,height: 3) } }
                }.buttonStyle(.plain).accessibilityElement(children: .combine).accessibilityValue(session.recipe.hasAdjustments(in: item) ? "Adjustments applied" : "No adjustments").accessibilityAddTraits(tool == item ? .isSelected : [])
            }
        }.background(StudioStyle.panel).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }
    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: tool == .color && (colorPanel == .wheels || colorPanel == .mixer) ? 12 : 22) {
                HStack(alignment: .top) {
                    if tool == .color && colorPanel == .wheels {
                        wheelZoneMenu
                    } else if tool == .color && colorPanel == .mixer {
                        mixerChannelMenu
                    } else {
                        Text(tool == .curves ? "RGB curves" : tool.help).font(.system(size: 11)).foregroundStyle(StudioStyle.secondary).lineSpacing(3).fixedSize(horizontal: false,vertical: true)
                    }
                    Spacer(minLength: 10)
                    Menu {
                        Button("Reset \(tool.rawValue.lowercased())",systemImage: "arrow.counterclockwise") { session.change { $0.reset(tool) }; if tool == .crop { zoom = 1; offset = .zero } }.disabled(!session.recipe.hasAdjustments(in: tool))
                        Button("Reset entire photo",systemImage: "trash",role: .destructive) { reset = true }
                    } label: { Image(systemName: "arrow.counterclockwise").frame(width: 34,height: 34) }.accessibilityLabel("Reset options")
                }
                switch tool {
                case .light:
                    adjustment("Exposure",key: \.exposure,range: -3...3,unit: "EV")
                    adjustment("Contrast",key: \.contrast)
                    adjustment("Highlights",key: \.highlights)
                    adjustment("Shadows",key: \.shadows)
                    adjustment("Whites",key: \.whites)
                    adjustment("Blacks",key: \.blacks)
                case .color:
                    colorControls
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
                    if let lut = session.recipe.lut {
                        HStack {
                            Label(lut.name.isEmpty ? "Imported LUT" : lut.name,systemImage:"cube.transparent").font(.caption.weight(.medium)).lineLimit(2)
                            Spacer()
                            Button("Remove") { session.change { $0.lut = nil; $0.lutAmount = 1 } }.font(.caption).padding(.vertical,8)
                        }
                        adjustment("LUT strength",key: \.lutAmount,range:0...1,defaultValue:1)
                        Text("A LUT remaps colors for a consistent finish. Strength blends it with your edit; zero turns it off.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }
                    Button { presets = true } label: { Label("Import LUT or save a look",systemImage:"cube.transparent").font(.caption).padding(.vertical,8) }
                    adjustment("Grain",key: \.grain,range: 0...1)
                    adjustment("Bloom",key: \.bloom,range: 0...1)
                    adjustment("Fade",key: \.fade,range: 0...1)
                    adjustment("Vignette",key: \.vignette,range: 0...1)
                case .curves:
                    curveControls
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
                    HStack {
                        Button { session.change { $0.geometry.flipHorizontal.toggle() } } label: { Label("Flip H",systemImage:"arrow.left.and.right.righttriangle.left.righttriangle.right").frame(maxWidth:.infinity) }
                        Button { session.change { $0.geometry.flipVertical.toggle() } } label: { Label("Flip V",systemImage:"arrow.up.and.down.righttriangle.up.righttriangle.down").frame(maxWidth:.infinity) }
                    }.buttonStyle(.bordered).font(.caption)
                    if session.recipe.crop == .free {
                        adjustment("Crop width (%)",key:\.geometry.width,range:0.1...1,defaultValue:1)
                        adjustment("Crop height (%)",key:\.geometry.height,range:0.1...1,defaultValue:1)
                    }
                    adjustment("Horizontal perspective",key:\.geometry.horizontal,range:-0.3...0.3)
                    adjustment("Vertical perspective",key:\.geometry.vertical,range:-0.3...0.3)
                    adjustment("Straighten",key: \.straighten,range: -15...15,unit: "°")
                    if session.recipe.crop != .original, let source = session.source {
                        let size = PhotoFraming.orientedSize(source.image.extent.size,recipe: session.recipe)
                        let window = PhotoFraming.window(in: size,recipe: session.recipe)
                        if size.width-window.width > 1 { adjustment("Horizontal framing",key: \.cropX,range: 0...1,defaultValue: 0.5) }
                        if size.height-window.height > 1 { adjustment("Vertical framing",key: \.cropY,range: 0...1,defaultValue: 0.5) }
                    }
                    Text("Choose Free to resize width and height independently, then drag the photo to position it. Perspective straightens leaning buildings; some edges are trimmed. Straightening automatically trims the edges to avoid black corners. Tap any adjustment number for an exact value.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
            }.padding(20).padding(.bottom,12)
        }.scrollIndicators(.hidden)
    }
    private var colorControls: some View {
        VStack(alignment:.leading,spacing: colorPanel == .wheels || colorPanel == .mixer ? 12 : 18) {
            Picker("Color tools",selection:$colorPanel) {
                ForEach(ColorPanel.allCases,id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if colorPanel == .global {
                adjustment("Warmth",key: \.warmth)
                adjustment("Tint",key: \.tint)
                adjustment("Saturation",key: \.saturation)
                adjustment("Vibrance",key: \.vibrance)
            } else if colorPanel == .wheels {
                wheelControls
            } else if colorPanel == .mixer {
                mixerControls
            } else {
                ColorRangePicker(selected:$selectedRange,adjustments:session.recipe.selectiveColors)
                HStack {
                    Text(selectedRange.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { showRange.toggle() } label: { Label("Show range",systemImage:showRange ? "eye.fill" : "eye").font(.caption).foregroundStyle(showRange ? StudioStyle.blue : StudioStyle.secondary) }.accessibilityValue(showRange ? "On" : "Off")
                    Button("Reset range") { session.change { $0.selectiveColors[keyPath:selectedRange.key] = ColorRangeAdjustment() } }
                        .font(.caption).disabled(session.recipe.selectiveColors[keyPath:selectedRange.key].isNeutral)
                }
                adjustment("Hue",key:selectedRange.recipeKey(\.hue),range:-30...30,unit:"°")
                adjustment("Saturation",key:selectedRange.recipeKey(\.saturation))
                adjustment("Brightness",key:selectedRange.recipeKey(\.brightness))
                Text(showRange ? "Selected colors stay visible; other colors dim. This inspection view skips wheels, mixer and film effects. It is never exported." : "Hue shifts this color, saturation changes its richness, and brightness makes it lighter or darker. Similar colors throughout the photo change together.")
                    .font(.caption).foregroundStyle(StudioStyle.secondary).lineSpacing(3)
            }
        }
    }
    private var wheelZoneMenu: some View {
        Menu {
            ForEach(WheelZone.allCases) { zone in
                Button(zone.rawValue + (session.recipe.colorWheels[keyPath:zone.key].isNeutral ? "" : " •")) { wheelZone = zone }
            }
            Divider()
            Button("Reset this wheel") { session.change { $0.colorWheels[keyPath:wheelZone.key] = WheelGrade() } }.disabled(session.recipe.colorWheels[keyPath:wheelZone.key] == WheelGrade())
            Button("Reset all wheels") { session.change { $0.colorWheels = ColorWheels() } }.disabled(session.recipe.colorWheels == ColorWheels())
        } label: { HStack(spacing:6) { Text(wheelZone.rawValue); Image(systemName:"chevron.down").font(.system(size:10)) }.font(.subheadline.weight(.medium)).frame(minHeight:34) }.accessibilityLabel("Choose wheel tone range")
    }
    private var mixerChannelMenu: some View {
        Menu {
            ForEach(MixerChannel.allCases) { channel in
                Button(channel.rawValue + " output" + (session.recipe.channelMixer.isNeutral(channel:channel) ? "" : " •")) { mixerChannel = channel }
            }
            Divider()
            Button("Reset this output") { session.change { $0.channelMixer.reset(mixerChannel) } }.disabled(session.recipe.channelMixer.isNeutral(channel:mixerChannel))
            Button("Reset mixer") { session.change { $0.channelMixer = ChannelMixer() } }.disabled(session.recipe.channelMixer.isNeutral)
        } label: { HStack(spacing:6) { Text(mixerChannel.rawValue + " output"); Image(systemName:"chevron.down").font(.system(size:10)) }.font(.subheadline.weight(.medium)).frame(minHeight:34) }.accessibilityLabel("Choose mixer output channel")
    }
    private var wheelControls: some View {
        VStack(alignment:.leading,spacing:14) {
            GeometryReader { geometry in
                let side = min(150,max(110,geometry.size.width*0.43))
                HStack(spacing:12) {
                    GradingWheel(session:session,zone:wheelZone).frame(width:side,height:side)
                    VStack(spacing:8) {
                        adjustment("Hue",key:wheelZone.recipeKey(\.hue),range:0...360,unit:"°")
                        adjustment("Strength",key:wheelZone.recipeKey(\.strength),range:0...1)
                        adjustment("Brightness",key:wheelZone.recipeKey(\.exposure),range:-1...1,unit:"EV")
                    }.frame(maxWidth:.infinity)
                }.frame(height:190)
            }.frame(height:190)
            Text(wheelZone.help).font(.caption).foregroundStyle(StudioStyle.secondary).lineSpacing(2)
            DisclosureGroup("Tone blending") {
                VStack(alignment:.leading,spacing:16) {
                    adjustment("Balance",key: \.colorWheels.balance)
                    adjustment("Blend",key: \.colorWheels.blend,range:0...1,defaultValue:0.5)
                    Toggle("Keep brightness",isOn:Binding(get:{ session.recipe.colorWheels.preserveBrightness },set:{ value in session.change { $0.colorWheels.preserveBrightness = value } })).font(.subheadline)
                    Text("Balance shifts the dark/bright split. Blend softens transitions between the three tonal wheels; Global applies everywhere. Keep brightness limits brightness changes from the tint; the brightness slider still works.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(.top,12)
            }.font(.caption)
        }
    }
    private var mixerControls: some View {
        VStack(alignment:.leading,spacing:16) {
            ForEach(MixerChannel.allCases) { input in
                adjustment(input.rawValue + " input",key:mixerChannel.recipeKey(input),range:-2...2,defaultValue:input == mixerChannel ? 1 : 0)
            }
            Toggle("Monochrome",isOn:Binding(get:{ session.recipe.channelMixer.monochrome },set:{ value in session.change { $0.channelMixer.monochrome = value } })).font(.subheadline)
            Text("Build the \(mixerChannel.rawValue.lowercased()) output from the photo's red, green and blue inputs. 100 keeps an input at full strength; 0 removes it. Monochrome makes the mixed result black and white.").font(.caption).foregroundStyle(StudioStyle.secondary).lineSpacing(2)
            DisclosureGroup("Offset and quick actions") {
                VStack(alignment:.leading,spacing:14) {
                    adjustment("Offset",key:mixerChannel.recipeOffsetKey,range:-0.5...0.5)
                    Text("Offset adds a fixed amount to this output channel.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    Button("Swap red and blue") { session.change { $0.channelMixer.swapRedAndBlue() } }.font(.subheadline)
                }.padding(.top,12)
            }.font(.caption)
        }
    }
    private var curveControls: some View {
        VStack(alignment:.leading,spacing:12) {
            Picker("Curve channel",selection:$curveChannel) {
                ForEach(CurveChannel.allCases) { channel in Text(channel.rawValue + (session.recipe.rgbCurves[keyPath:channel.key].isNeutral ? "" : " •")).tag(channel) }
            }.pickerStyle(.segmented)
            HStack {
                Menu {
                    ForEach(CurvePoint.allCases) { point in Button(point.title) { curvePoint = point } }
                    Divider()
                    Button("Reset point") { session.change { $0[keyPath:curveChannel.recipeKey(curvePoint)] = curvePoint.input } }
                    Button("Reset \(curveChannel.rawValue.lowercased()) curve") { session.change { $0.rgbCurves[keyPath:curveChannel.key] = ToneCurve() } }
                } label: { HStack(spacing:5) { Text(curvePoint.title); Image(systemName:"chevron.down").font(.system(size:9)) }.font(.caption) }
                Spacer()
                Button {
                    let key = curveChannel.recipeKey(curvePoint)
                    numericEdit = NumericEdit(name:curvePoint.title,key:key,range:0...1,unit:"")
                    numericText = String(format:"%.2f",session.recipe[keyPath:key]*100)
                } label: { Text(String(format:"%.1f%%",session.recipe[keyPath:curveChannel.recipeKey(curvePoint)]*100)).font(.caption.monospacedDigit()).foregroundStyle(curveChannel.color).padding(.vertical,5) }.accessibilityLabel("Set exact curve output")
            }
            RGBCurveGraph(session:session,channel:curveChannel,selected:$curvePoint).frame(height:170)
            Text(curveChannel.help).font(.caption).foregroundStyle(StudioStyle.secondary).lineSpacing(2)
            DisclosureGroup("Additional tone shaping") {
                VStack(spacing:18) {
                    adjustment("Dark tones",key: \.curveShadows)
                    adjustment("Middle tones",key: \.curveMidtones)
                    adjustment("Bright tones",key: \.curveHighlights)
                }.padding(.top,14)
            }.font(.caption).padding(.top,4)
        }
    }
    private func adjustment(_ name: String,key: WritableKeyPath<Recipe,Double>,range: ClosedRange<Double> = -1...1,unit: String = "",defaultValue: Double = 0) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(name).font(.system(size: 13,weight: .medium))
                Spacer()
                Button {
                    let edit = NumericEdit(name: name,key: key,range: range,unit: unit)
                    numericText = String(format: "%.2f",session.recipe[keyPath: key] * edit.multiplier)
                    numericEdit = edit
                } label: {
                    Text(unit == "EV" ? String(format: "%+.2f EV",session.recipe[keyPath: key]) : unit == "°" ? String(format: "%+.1f°",session.recipe[keyPath: key]) : String(format: "%+.0f",session.recipe[keyPath: key] * 100))
                        .font(.system(size: 11,weight: .medium,design: .monospaced)).foregroundStyle(session.recipe[keyPath: key] == defaultValue ? StudioStyle.secondary : StudioStyle.blue)
                        .padding(.vertical,5).padding(.leading,8)
                }.buttonStyle(.plain).accessibilityLabel("Set exact \(name.lowercased())")
            }
            Slider(value: Binding(get: { session.recipe[keyPath: key] },set: { session.recipe[keyPath: key] = $0 }),in: range,onEditingChanged: { editing in if editing { session.begin() } else { session.end() } })
                .accessibilityLabel(name)
        }.contentShape(Rectangle()).onTapGesture(count: 2) { session.change { $0[keyPath: key] = defaultValue } }
    }
    private func moveCrop(_ value: DragGesture.Value, previewSize: CGSize) {
        guard let source = session.source else { return }
        if cropDragStart == nil { cropDragStart = CGSize(width: session.recipe.cropX,height: session.recipe.cropY); session.begin() }
        guard let initial = cropDragStart else { return }
        let size = PhotoFraming.orientedSize(source.image.extent.size,recipe: session.recipe)
        let window = PhotoFraming.window(in: size,recipe: session.recipe)
        let scale = min(previewSize.width/window.width,previewSize.height/window.height)
        if size.width-window.width > 1 { session.recipe.cropX = min(1,max(0,Double(initial.width-value.translation.width / scale / (size.width-window.width)))) }
        if size.height-window.height > 1 { session.recipe.cropY = min(1,max(0,Double(initial.height-value.translation.height / scale / (size.height-window.height)))) }
    }
    private func runPreviewCheckIfRequested() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--verify-preview") else { return }
        let documents = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask)[0]
        func writeProgress(_ payload: [String: Any]) {
            if let data = try? JSONSerialization.data(withJSONObject: payload,options:.prettyPrinted) { try? data.write(to:documents.appendingPathComponent("preview-progress.json"),options:.atomic) }
        }
        guard session.source != nil else { writeProgress(["stage":"source failed","error":session.error ?? "No preview source"]); return }
        writeProgress(["stage":"starting","active":UIApplication.shared.applicationState == .active])
        let priorIdleSetting = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        diagnosticsRunning = true
        let initialRecipe = session.recipe
        defer { session.recipe = initialRecipe; diagnosticsRunning = false; UIApplication.shared.isIdleTimerDisabled = priorIdleSetting }
        for _ in 0..<30 {
            if UIApplication.shared.applicationState == .active { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .seconds(1))
        PreviewMetrics.shared.times = []; PreviewMetrics.shared.failures = 0
        let start = ProcessInfo.processInfo.thermalState.rawValue
        let began = CACurrentMediaTime()
        session.recipe.lut = try? await Task.detached(priority:.userInitiated) { try LUTVerification.example(dimension:65) }.value
        session.recipe.look = .daylight; session.recipe.grain = 0.15; session.recipe.bloom = 0.1
        session.recipe.straighten = 3; session.recipe.crop = .portrait
        let steps = ProcessInfo.processInfo.arguments.contains("--sustained-preview") ? 7200 : 180
        var interrupted = false
        for index in 0..<steps {
            if Task.isCancelled || UIApplication.shared.applicationState != .active { interrupted = true; break }
            if index % 120 == 0 { writeProgress(["stage":"running","step":index,"rendered":PreviewMetrics.shared.times.count,"active":UIApplication.shared.applicationState == .active]) }
            session.recipe.lutAmount = 0.5 + sin(Double(index)*0.1)*0.5
            session.recipe.exposure = sin(Double(index) * 0.13)
            session.recipe.warmth = cos(Double(index) * 0.11) * 0.4
            session.recipe.rgbCurves.red.middle = 0.5 + sin(Double(index)*0.07)*0.06
            session.recipe.selectiveColors.blue.saturation = sin(Double(index)*0.09)*0.35
            session.recipe.selectiveColors.orange.hue = cos(Double(index)*0.08)*8
            session.recipe.colorWheels.shadows.hue = 220 + sin(Double(index)*0.04)*20
            session.recipe.colorWheels.shadows.strength = 0.12
            session.recipe.colorWheels.midtones.hue = 30; session.recipe.colorWheels.midtones.strength = 0.06
            session.recipe.colorWheels.highlights.hue = 40; session.recipe.colorWheels.highlights.strength = 0.08
            session.recipe.colorWheels.global.exposure = sin(Double(index)*0.05)*0.08
            session.recipe.channelMixer.redGreen = sin(Double(index)*0.06)*0.05
            try? await Task.sleep(for: .milliseconds(16))
        }
        try? await Task.sleep(for: .seconds(1))
        let count = PreviewMetrics.shared.times.count
        try? await Task.sleep(for: .seconds(3))
        let times = PreviewMetrics.shared.times.sorted()
        let report: [String: Any] = ["interrupted":interrupted,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","elapsedSeconds":CACurrentMediaTime()-began,"cancelled":Task.isCancelled,"requestedUpdates": steps,"rendered": count,"kernelBackend":ColorPipeline.backend,"p95Milliseconds": times.isEmpty ? 0 : times[Int(Double(times.count-1)*0.95)],"extraIdleFrames": times.count-count,"gpuFailures": PreviewMetrics.shared.failures,"thermalStart": start,"thermalEnd": ProcessInfo.processInfo.thermalState.rawValue]
        if let data = try? JSONSerialization.data(withJSONObject: report,options: .prettyPrinted) {
            try? data.write(to: documents.appendingPathComponent("preview-verification.json"),options: .atomic)
            writeProgress(["stage":"finished","rendered":count])
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
            let values = [recipe.fade * 0.15 + recipe.blacks * 0.08,0.25+recipe.curveShadows*0.15+recipe.blacks*0.04,0.5+recipe.curveMidtones*0.2,0.75+recipe.curveHighlights*0.15+recipe.whites*0.04,1+recipe.whites*0.16]
            var curve = Path(); curve.move(to: CGPoint(x: 0,y: size.height*(1-values[0])))
            for n in 1...4 { curve.addLine(to: CGPoint(x: CGFloat(n)/4*size.width,y: size.height*(1-values[n]))) }
            context.stroke(curve,with: .color(StudioStyle.blue),style: StrokeStyle(lineWidth: 2,lineCap: .round,lineJoin: .round))
        }.accessibilityLabel("Tone curve overview")
    }
}
