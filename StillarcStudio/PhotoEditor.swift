import SwiftUI
import CoreImage
import Photos
import UniformTypeIdentifiers

@MainActor struct PhotoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: EditSession
    @Bindable var library: StudioLibrary
    var pool:EditingPool? = nil
    @State private var poolChanging=false
    @State private var poolComparison=false
    @State private var poolLookMatch=false
    @State private var poolSync=false
    @State private var poolClipboard:AdjustmentClipboard?
    @State private var scopesVisible = false
    @State private var scopeMode = ScopeMode.histogram
    @State private var scopeSampler = ScopeSampler()
    @State private var automaticTarget:AutomaticSelectionTarget?
    @State private var correctionMask:LocalMask?
    @State private var trackingMask:LocalMask?
    @State private var matteReview:LocalMask?
    @State private var peopleMatte:PeopleMatteTarget?
    @State private var selectedMaskID:UUID?
    @State private var showMask = true
    @State private var brushMode = BrushInteractionMode.paint
    @State private var tool: Tool = .light
    @State private var colorPanel: ColorPanel = .global
    @State private var wheelZone: WheelZone = .shadows
    @State private var mixerChannel: MixerChannel = .red
    @State private var selectedRange: ColorRange = .orange
    @State private var showRange = false
    @State private var curveChannel: CurveChannel = .master
    @State private var curvePoint: CurvePoint = .middle
    @State private var curveEditing = false
    @State private var comparing = false
    @State private var splitComparison = false
    @State private var splitPosition = 0.5
    @State private var versionsSheet = false
    @State private var transferSheet:AdjustmentTransferMode?
    @State private var videoPosition=ClipPosition()
    @State private var animationSheet=false
    @State private var warpSheet=false
    @State private var referenceSheet=false
    @State private var photoDevelopment=false
    @State private var backgroundSheet=false
    @State private var retouchSheet=false
    @State private var detailSheet=false
    @State private var sdrProof=false
    @State private var export = false
    @State private var presets = false
    @State private var inputSheet = false
    @State private var sampleTool:PointSampleTool?
    @State private var trimSheet = false
    @State private var reset = false
    @State private var numericEdit: NumericEdit?
    @State private var numericText = ""
    @State private var diagnosticsRunning = false
    @State private var cropDisplayFinal = false
    @State private var cropFocused = false
    @State private var cropEditing = false
    @State private var cropResumeID = 0
    @State private var cropAwaitingAdjustment = false
    @State private var controlsHidden = false
    @State private var automaticRefineExpanded = false
    @State private var maskZoom=1.0
    @State private var maskOffset=CGSize.zero
    @State private var maskNavigating=true
    @State private var zoom = 1.0
    @GestureState private var pinch = 1.0
    @State private var offset = CGSize.zero
    @GestureState private var drag = CGSize.zero
    init(project: Project, library: StudioLibrary,pool:EditingPool? = nil) { _session = State(initialValue: EditSession(project)); self.library = library;self.pool=pool;_tool=State(initialValue:pool?.tool ?? .light) }
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
                        VStack(spacing: 0) { scopePanel;tools; controls }.frame(width: controlsHidden ? 0 : 340).clipped().background(StudioStyle.panel)
                    }
                } else {
                    VStack(spacing: 0) {
                        preview
                        scopePanel
                        tools
                        controls.frame(height: controlsHidden ? 0 : min(210,geometry.size.height * 0.30)).clipped().background(StudioStyle.panel)
                    }
                }
            }
            if let pool {poolBar(pool)}
        }
        }.background(StudioStyle.ink).tint(StudioStyle.blue)
        .disabled(poolChanging || pool?.historyBusy == true)
        .task {
            await session.open(library: library)
            if let pool {let id=session.project.id;session.historyRecorder={before,after in pool.recordEdit(id:id,before:before,after:after)}}
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--matte-repair-demo"),let video=session.project.video {
                var r=Recipe();r.masks=[Batch052Verification.layer(duration:video.duration)];r.background=PhotoBackground(mode:.solid,red:0,green:0,blue:1);session.change {$0=r};selectedMaskID=r.masks[0].id;tool = .masks
                try? await Task.sleep(for:.milliseconds(500));matteReview=r.masks[0]
            }
            if arguments.contains("--correction-demo") {
                let end=session.project.video?.duration ?? 2
                var layer=LocalMask(kind:.radial);layer.centerX=0.35;layer.width=0.2;layer.height=0.3;layer.exposure=0.7
                layer.motion=MaskMotion(framing:MaskMotion.signature(session.recipe),start:0,end:end,points:[.init(time:0,x:0,y:0),.init(time:end,x:0.15,y:0)])
                session.change {$0.masks=[layer]};selectedMaskID=layer.id;tool = .masks
                try? await Task.sleep(for:.milliseconds(600));correctionMask=layer
            }
            if arguments.contains("--tracking-demo") {
                var layer = LocalMask(kind:.radial);layer.centerX = 0.3;layer.width = 0.14;layer.height = 0.14;layer.exposure = 0.5
                session.change { $0.masks = [layer] };selectedMaskID = layer.id;tool = .masks
                try? await Task.sleep(for:.seconds(1));trackingMask = layer
            }
            if arguments.contains("--reference-demo"),let url=Bundle.main.url(forResource:"Sample",withExtension:"jpg") {
                if let ref=try? await library.vault.importReference(url,project:session.project) {session.change {$0=Recipe();$0.reference=ref;$0.exposure = -0.6}}
            }
            if arguments.contains("--neutral-demo") { session.change { $0 = Recipe() } }
            if arguments.contains("--combined-lut-demo"),let asset=try? CombinedLUTVerification.example() {session.change {$0=Recipe();$0.lut=asset;$0.lutAmount=0.6}}
            if arguments.contains("--one-d-lut-demo"),let asset=try? OneDLUTVerification.example() {session.change {$0=Recipe();$0.lut=asset;$0.lutAmount=0.6;$0.lutLayers=[LUTLayer(asset:asset,amount:0.2)]}}
            if arguments.contains("--colour-stack-demo") {let a=try? LUTVerification.example();session.change {$0=Recipe();$0.lut=a;if let a {$0.lutLayers=[LUTLayer(asset:a,amount:0.5),LUTLayer(asset:a,amount:0.2)]}}}
            if arguments.contains("--brush-demo") {maskNavigating=false; var layer = LocalMask(kind:.brush);var drawing = BrushDrawing();let id = drawing.begin(point:BrushPoint(x:0.3,y:0.3),radius:0.08,feather:0.6,erase:false)!;drawing.append(BrushPoint(x:0.7,y:0.6),stroke:id);layer.brush = drawing;layer.exposure = 0.5;session.change { $0.masks = [layer] };selectedMaskID = layer.id;tool = .masks }
            if arguments.contains("--mask-demo") { var layer = LocalMask(kind:.radial);layer.exposure = 0.5;session.change { $0.masks = [layer] };selectedMaskID = layer.id;tool = .masks }
            if arguments.contains("--crop-mask-demo"),let prepared = session.source {
                let recipe = session.recipe,size = prepared.image.extent.size
                let stored = try? await Task.detached(priority:.utility) {
                    let bounds = CGRect(origin:.zero,size:size)
                    let shape = CIImage(color:.white).cropped(to:CGRect(x:0,y:size.height*0.5,width:size.width,height:size.height*0.5)).composited(over:CIImage(color:.black).cropped(to:bounds))
                    return try AutomaticMaskBitmap.make(shape,recipe:recipe,videoStart:nil)
                }.value
                if let stored { var layer = LocalMask(kind:.sky);layer.automatic = stored;layer.exposure = 0.4;session.change { $0.masks = [layer] } }
            }
            if arguments.contains("--split") { splitComparison = true }
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
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-versions-ui") {
                // Let the editor’s full-screen presentation finish before presenting a child sheet.
                try? await Task.sleep(for:.seconds(1))
                let start = CACurrentMediaTime(),players = VideoPlayback.creationCount,presentations = VersionsSheet.presentationCount
                for _ in 0..<5 { versionsSheet = true;try? await Task.sleep(for:.milliseconds(700));versionsSheet = false;try? await Task.sleep(for:.milliseconds(700)) }
                let result:[String:Any] = ["passed":VideoPlayback.creationCount-players<=1 && VersionsSheet.presentationCount-presentations == 5,"sheetsPresented":VersionsSheet.presentationCount-presentations,"cycles":5,"playersCreated":VideoPlayback.creationCount-players,"elapsedSeconds":CACurrentMediaTime()-start]
                let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("versions-ui-verification.json")
                if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
            }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-transfer-ui") {
                try? await Task.sleep(for:.seconds(1))
                let seeded = library.adjustmentClipboard == nil
                if seeded { await library.copyAdjustments(name:"Transfer UI check",recipe:Recipe(),sections:Set(AdjustmentSection.allCases)) }
                let players = VideoPlayback.creationCount,presentations = AdjustmentTransferSheet.presentedIDs.count,start = CACurrentMediaTime()
                for _ in 0..<5 {
                    transferSheet = .copy;try? await Task.sleep(for:.milliseconds(700));transferSheet = nil;try? await Task.sleep(for:.milliseconds(700))
                    transferSheet = .paste;try? await Task.sleep(for:.milliseconds(700));transferSheet = nil;try? await Task.sleep(for:.milliseconds(700))
                }
                if seeded { await library.clearCopiedAdjustments() }
                let count = AdjustmentTransferSheet.presentedIDs.count-presentations
                let result:[String:Any] = ["passed":count == 10 && VideoPlayback.creationCount-players<=1,"sheetsPresented":count,"playersCreated":VideoPlayback.creationCount-players,"elapsedSeconds":CACurrentMediaTime()-start]
                let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("transfer-ui-verification.json")
                if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
            }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-mask-ui") { await verifyMaskUI() }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-brush-ui") { await verifyBrushUI() }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-crop-ui") { await verifyCropUI() }
            #endif
            await runPreviewCheckIfRequested()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-editor-layout") {
                for _ in 0..<4 { export = true;try? await Task.sleep(for:.milliseconds(400));export = false;try? await Task.sleep(for:.milliseconds(400)) }
            }
            #endif
        }
        .task(id:developmentTaskKey) {await refreshPhotoSource()}
        .task(id:session.backgroundKey) {await session.warmBackground()}
        .sheet(isPresented:$animationSheet){VideoAnimationSheet(session:session,pool:pool,undoAction:{undoEdit()},redoAction:{undoEdit(redo:true)},initialTime:videoPosition.time,onFinish:{videoPosition.seek($0)})}
        .sheet(isPresented:$warpSheet) {ColorWarpSheet(session:session)}
        .sheet(isPresented:$referenceSheet) {ReferenceMatchSheet(session:session,library:library,pool:pool)}
        .sheet(isPresented:$photoDevelopment) {PhotoDevelopmentSheet(session:session,sdrProof:$sdrProof)}
        .sheet(isPresented:$backgroundSheet) {BackgroundSheet(session:session,library:library)}
        .sheet(isPresented:$retouchSheet) {RetouchSheet(session:session,undoAction:{undoEdit()},redoAction:{undoEdit(redo:true)})}
        .sheet(isPresented:$detailSheet) {DetailInspectionSheet(session:session)}
        .task(id:cropSettleKey) { await settleCropAndMasks() }
        .onChange(of:MaskMotion.signature(session.recipe)) { _,_ in cropAwaitingAdjustment = false;cropDisplayFinal = false;cropFocused = false }
        .onChange(of:tool) { _,_ in session.end();zoom=1;offset = .zero;maskNavigating = selectedMask?.kind != .brush || brushMode == .view;curveEditing = false; pool?.tool=tool; cropAwaitingAdjustment = false;cropDisplayFinal = false;cropFocused = false }
        .onChange(of:scopesActive) { _,value in scopeSampler.setEnabled(value) }
        .onDisappear { scopeSampler.setEnabled(false) }
        .onChange(of:session.project.id){_,_ in videoPosition.seek(0);maskZoom=1;maskOffset = .zero}
        .onChange(of:selectedMaskID){_,_ in session.end();maskNavigating = selectedMask?.kind != .brush || brushMode == .view}
        .onChange(of: session.recipe) { _, _ in if !diagnosticsRunning && pool?.historyBusy != true { session.scheduleSave(library) } }
        .onChange(of: phase) { _, phase in if phase != .active { curveEditing = false;session.end();if pool?.historyBusy != true {Task { await session.persist(library) }} } }
        .onDisappear {saveOnExit()}
        .sheet(isPresented:$poolComparison) {if let pool {PoolCompareSheet(projects:pool.projects(library),reference:session.project,vault:library.vault)}}
        .sheet(isPresented:$poolLookMatch) {if let pool {PoolLookMatchSheet(library:library,pool:pool,reference:session.project)}}
        .sheet(isPresented:$poolSync) {if let pool,let clipboard=poolClipboard {BatchPasteSheet(library:library,projects:pool.projects(library),clipboard:clipboard,pool:pool)}}
        .sheet(isPresented: $export) { ExportSheet(session: session,library:library,pool:pool) }
        .sheet(item:$transferSheet) { mode in AdjustmentTransferSheet(mode:mode,session:session,library:library) }
        .sheet(isPresented:$versionsSheet) { VersionsSheet(session:session,library:library) }
        .sheet(item:$automaticTarget) { target in AutomaticSelectionSheet(session:session,target:target) { id in selectedMaskID = id;showMask = !target.removeBackground } }
        .sheet(item:$correctionMask) { mask in MaskCorrectionSheet(session:session,maskID:mask.id,pool:pool,undoAction:{undoEdit()},redoAction:{undoEdit(redo:true)},initialTime:videoPosition.time,onFinish:{videoPosition.seek($0)}) }
        .sheet(item:$matteReview) {layer in VideoMatteReviewSheet(session:session,maskID:layer.id,initialTime:videoPosition.time,onFinish:{videoPosition.seek($0)},undoAction:{undoEdit()},redoAction:{undoEdit(redo:true)})}
        .sheet(item:$peopleMatte) {target in PeopleVideoMatteSheet(session:session,target:target) {id in selectedMaskID=id;showMask = !target.cutout}}
        .sheet(item:$trackingMask) { mask in MaskTrackingSheet(session:session,maskID:mask.id) }
        .sheet(isPresented: $presets) { PresetsSheet(session: session,library: library) }
        .sheet(isPresented:$trimSheet) { VideoTrimSheet(session:session) }
        .sheet(item:$sampleTool) {tool in PointSampleSheet(session:session,tool:tool,initialTime:videoPosition.time,undoAction:{undoEdit()},redoAction:{undoEdit(redo:true)})}
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
    private func verifyCropUI() async {
        let original = session.recipe,priorTool = tool,priorIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { session.recipe = original;tool = priorTool;UIApplication.shared.isIdleTimerDisabled = priorIdle }
        tool = .crop;zoom = 1;offset = .zero;splitComparison = false;cropEditing = true
        defer { cropEditing = false }
        guard let source = session.source else { return }
        session.recipe.crop = .portrait;session.recipe.geometry.cropScale = 0.8
        try? await Task.sleep(for:.seconds(2))
        let base = session.recipe,size = PhotoFraming.orientedSize(source.image.extent.size,recipe:base)
        PreviewMetrics.shared.times = [];PreviewMetrics.shared.failures = 0
        let thermal = ProcessInfo.processInfo.thermalState.rawValue,players = VideoPlayback.creationCount
        var maxDelay = 0.0,interrupted = false
        for i in 0..<180 {
            guard UIApplication.shared.applicationState == .active else { interrupted = true;break }
            let start = CACurrentMediaTime(),d = 50*sin(Double(i)*0.1)
            session.recipe = CropEditingGeometry.resize(base,size:size,corner:.bottomRight,delta:CGSize(width:d,height:d))
            try? await Task.sleep(for:.milliseconds(16));maxDelay = max(maxDelay,CACurrentMediaTime()-start)
        }
        let dragRenders = PreviewMetrics.shared.times.count
        cropEditing = false
        try? await Task.sleep(for:.seconds(3))
        let fittedRenders = PreviewMetrics.shared.times.count-dragRenders,fitted = cropDisplayFinal
        let settled = PreviewMetrics.shared.times.count
        try? await Task.sleep(for:.seconds(2))
        let idleRenders = PreviewMetrics.shared.times.count-settled
        let result:[String:Any] = ["version":"0.20.0","fittedCropRenders":fittedRenders,"fittedAfterDelay":fitted,"passed":!interrupted && fitted && dragRenders == 0 && fittedRenders<=2 && idleRenders == 0 && PreviewMetrics.shared.failures == 0 && VideoPlayback.creationCount == players && maxDelay<0.25,"updates":180,"dragImageRenders":dragRenders,"idleImageRenders":idleRenders,"playersCreated":VideoPlayback.creationCount-players,"maxMainActorWakeSeconds":maxDelay,"thermalStart":thermal,"thermalEnd":ProcessInfo.processInfo.thermalState.rawValue,"interrupted":interrupted]
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("crop-ui-verification.json")
        if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
    }
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
    #if DEBUG
    private func verifyMaskUI() async {
        let original = session.recipe,undo = session.undoStack,redo = session.redoStack,previousTool = tool,previousID = selectedMaskID
        let oldIdle = UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled = true;diagnosticsRunning = true
        defer { session.recipe = original;session.undoStack = undo;session.redoStack = redo;tool = previousTool;selectedMaskID = previousID;diagnosticsRunning = false;UIApplication.shared.isIdleTimerDisabled = oldIdle }
        try? await Task.sleep(for:.seconds(1))
        let players = VideoPlayback.creationCount
        tool = .masks;splitComparison = false;session.recipe.masks = []
        var delays = [Double]()
        for i in 0..<4 { var layer = LocalMask(kind:[LocalMaskKind.color,.luminance,.radial,.linear][i]);layer.combination = i == 0 ? nil : [.intersect,.add,.subtract][i-1];session.change { $0.masks.append(layer) };selectedMaskID = layer.id;try? await Task.sleep(for:.milliseconds(100)) }
        for step in 0..<180 {
            let began = CACurrentMediaTime()
            if session.recipe.masks.count == 4 { session.recipe.masks[0].selection?.hue = Double(step*2);session.recipe.masks[0].exposure = 0.5;session.recipe.masks[1].selection?.upper = 0.6+sin(Double(step)*0.04)*0.3;session.recipe.masks[1].inverted = step%30<15;selectedMaskID = session.recipe.masks[step%2].id }
            showMask = step%60<40
            try? await Task.sleep(for:.milliseconds(16));delays.append(CACurrentMediaTime()-began)
        }
        let count = session.recipe.masks.count
        session.change { $0.masks.removeAll() };session.undo()
        let undoOK = session.recipe.masks.count == count && count == 4
        let result:[String:Any] = ["passed":undoOK && (delays.max() ?? 99)<1 && VideoPlayback.creationCount-players<=1,"layers":count,"updates":180,"undoDeletion":undoOK,"playersCreated":VideoPlayback.creationCount-players,"maxMainActorDelaySeconds":delays.max() ?? 0]
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("mask-ui-verification.json")
        if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
    }
    #endif
    #if DEBUG
    private func verifyBrushUI() async {
        let original = session.recipe,undo = session.undoStack,redo = session.redoStack,previousTool = tool,previousID = selectedMaskID,previousMode = brushMode
        let idle = UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled = true;diagnosticsRunning = true
        defer { session.recipe = original;session.undoStack = undo;session.redoStack = redo;tool = previousTool;selectedMaskID = previousID;brushMode = previousMode;diagnosticsRunning = false;UIApplication.shared.isIdleTimerDisabled = idle }
        try? await Task.sleep(for:.seconds(1))
        var layer = LocalMask(kind:.brush);layer.exposure = 0.5
        session.recipe.masks = [layer];selectedMaskID = layer.id;tool = .masks;brushMode = .paint;showMask = true;splitComparison = false
        let players = VideoPlayback.creationCount,jobsBefore = BrushMaskRasterizer.statistics()["jobs"] ?? 0
        var delays = [Double]()
        let stroke = session.recipe.masks[0].brush!.begin(point:BrushPoint(x:0.2,y:0.3),radius:0.05,feather:0.6,erase:false)!
        for step in 0..<180 {
            let began = CACurrentMediaTime()
            session.recipe.masks[0].brush!.append(BrushPoint(x:0.5+sin(Double(step)*0.08)*0.3,y:0.5+cos(Double(step)*0.06)*0.2),stroke:stroke)
            if step%60 == 0 { brushMode = step%120 == 0 ? .view : .paint }
            try? await Task.sleep(for:.milliseconds(16));delays.append(CACurrentMediaTime()-began)
        }
        brushMode = .erase
        let erase = session.recipe.masks[0].brush!.begin(point:BrushPoint(x:0.5,y:0.5),radius:0.04,feather:0.6,erase:true)!
        session.recipe.masks[0].brush!.append(BrushPoint(x:0.6,y:0.5),stroke:erase)
        try? await Task.sleep(for:.milliseconds(500))
        let count = BrushMaskRasterizer.statistics()["jobs"] ?? 0
        try? await Task.sleep(for:.seconds(3))
        let idleJobs = (BrushMaskRasterizer.statistics()["jobs"] ?? 0)-count
        let result:[String:Any] = ["passed":count>jobsBefore && idleJobs == 0 && (delays.max() ?? 99)<1 && VideoPlayback.creationCount-players<=1,"updates":180,"rasterJobs":count-jobsBefore,"idleRasterJobs":idleJobs,"playersCreated":VideoPlayback.creationCount-players,"maxMainActorDelaySeconds":delays.max() ?? 0,"raster":BrushMaskRasterizer.statistics()]
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("brush-ui-verification.json")
        if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
    }
    #endif
    private var developmentTaskKey:String {session.developmentKey+":"+String(export)+":"+String(describing:phase)}
    private func refreshPhotoSource() async {if !export && phase == .active {await session.refreshDevelopment()}}
    private func saveOnExit() {guard pool?.historyBusy != true else {return};Task {_ = await session.persist(library)}}
    private var cropSettleKey:String { "\(MaskMotion.signature(session.recipe))|\(session.recipe.video.start)|\(tool.rawValue)|\(cropEditing)|\(cropAwaitingAdjustment)|\(cropResumeID)|\(phase)|\(export)|\(session.source != nil)|\(pool?.historyBusy == true)|\(poolChanging)" }
    private func settleCropAndMasks() async {
        guard !cropEditing,!cropAwaitingAdjustment,!poolChanging,pool?.historyBusy != true,phase == .active,!export,let url = session.sourceURL,let prepared = session.source else { return }
        do {
            try await Task.sleep(for:.milliseconds(700))
            try Task.checkCancellation()
            if tool == .crop { withAnimation(reduceMotion ? nil : .timingCurve(0.2,0.8,0.2,1,duration:0.4)) { cropFocused = true } }
            let snapshot = session.recipe
            if snapshot.masks.contains(where:{ $0.kind.isAutomatic && $0.automatic?.matches(snapshot) == false }) {
                let video = session.project.video
                let worker = Task.detached(priority:.utility) { try await MaskFramingRepair.repair(recipe:snapshot,url:url,video:video,prepared:prepared) }
                let repaired = try await withTaskCancellationHandler(operation:{ try await worker.value },onCancel:{ worker.cancel() })
                guard !Task.isCancelled,MaskMotion.signature(session.recipe) == MaskMotion.signature(snapshot),session.recipe.video.start == snapshot.video.start else { return }
                session.recipe.masks = MaskFramingRepair.merge(repaired,snapshot:snapshot,current:session.recipe)
            }
            if tool == .crop && cropFocused { try await Task.sleep(for:.milliseconds(reduceMotion ? 0 : 440));cropDisplayFinal = true }
        } catch is CancellationError {} catch { /* Export retries repair and provides an actionable error if needed. */ }
    }
    private func resumeCrop() { cropAwaitingAdjustment = true;cropDisplayFinal = false;withAnimation(reduceMotion ? nil : .easeOut(duration:0.3)) { cropFocused = false };cropResumeID += 1 }
    private func undoEdit(redo:Bool=false) {
        guard let pool else {if redo {session.redo()} else {session.undo()};return}
        guard !pool.historyBusy else {return}
        session.pauseAutosave();pool.historyBusy=true
        Task { @MainActor in
            defer {pool.historyBusy=false}
            guard await session.persist(library) else {session.error=library.error ?? "Could not save before undo.";return}
            do {
                try await pool.moveHistory(undo: !redo,library:library)
                if let updated=library.projects.first(where:{$0.id==session.project.id}) {session.adoptHistory(updated)}
            } catch {session.error=error.localizedDescription}
        }
    }
    private func removeBackground() {
        guard !session.project.isVideo else {return}
        if let layer=session.recipe.masks.first(where:{$0.kind == .subject && !$0.inverted && $0.automatic?.matches(session.recipe)==true}) {
            session.change {$0.setCutout(layer.id,enabled:true)};selectedMaskID=layer.id;showMask=false
        } else if session.recipe.masks.count<4 {automaticTarget=AutomaticSelectionTarget(kind:.subject,maskID:nil,removeBackground:true)}
    }
    private func browsePool(_ step:Int) {
        guard let pool else {return};let next=pool.index+step
        guard pool.state.ids.indices.contains(next) else {return};switchPool(pool.state.ids[next])
    }
    private func switchPool(_ id:UUID) {
        guard let pool,id != pool.state.active,!poolChanging,!session.busy else {return}
        poolChanging=true
        Task { @MainActor in
            if await session.retire(library) {pool.activate(id)}
            else {session.error=library.error ?? "Could not save this item. Try again.";poolChanging=false}
        }
    }
    private func startPoolMatch() {
        guard pool != nil,!poolChanging,!session.busy else {return}
        Task { @MainActor in session.end();if await session.persist(library) {poolLookMatch=true} }
    }
    private func syncPool() {
        guard pool != nil,!poolChanging,!session.busy else {return}
        poolChanging=true
        Task { @MainActor in
            session.end()
            if await session.persist(library) {
                poolClipboard=AdjustmentClipboard(name:session.project.name,recipe:session.recipe,sections:Set(AdjustmentSection.allCases));poolSync=true
            } else {session.error=library.error ?? "Could not save this item."}
            poolChanging=false
        }
    }
    private func poolBar(_ pool:EditingPool) -> some View {
        VStack(spacing:4) {
            HStack(spacing:10) {
                Button {browsePool(-1)} label:{Image(systemName:"chevron.left").frame(width:28,height:30)}.disabled(pool.index==0 || session.busy).accessibilityLabel("Previous pool item")
                Text("\(pool.index+1) / \(pool.state.ids.count)").font(.caption.monospaced()).accessibilityIdentifier("poolPosition")
                Button {browsePool(1)} label:{Image(systemName:"chevron.right").frame(width:28,height:30)}.disabled(pool.index+1==pool.state.ids.count || session.busy).accessibilityLabel("Next pool item")
                Spacer(minLength:0)
                Button {pool.selecting.toggle()} label:{Label("\(pool.state.selected.count)",systemImage:pool.selecting ? "checkmark.circle.fill":"checkmark.circle")}.accessibilityLabel("Select pool items").accessibilityValue(pool.selecting ? "Selecting":"Browsing").contextMenu {
                    Button("Select all pool items") {pool.state.selected=Set(pool.state.ids);pool.save()}
                    Button("Clear pool selection") {pool.state.selected=[];pool.save()}
                }
                Button("Sync edits",action:syncPool).disabled(session.busy).accessibilityIdentifier("syncPoolEdits").contextMenu {Button("Match pool to this edit"){startPoolMatch()}
                    Button("Compare pool shots"){Task {session.end();if await session.persist(library) {poolComparison=true}}}
                    Button("Select same media type"){pool.state.selected=Set(pool.projects(library).filter {$0.isVideo==session.project.isVideo}.map(\.id));pool.selecting=true;pool.save()}
                    Button("Select same input profile"){pool.state.selected=Set(pool.projects(library).filter {$0.recipe.input.profile==session.recipe.input.profile}.map(\.id));pool.selecting=true;pool.save()}}
                Button {pool.collapsed.toggle()} label:{Image(systemName:pool.collapsed ? "chevron.down":"chevron.up").frame(width:24,height:30)}.accessibilityLabel(pool.collapsed ? "Show filmstrip":"Hide filmstrip")
            }.font(.caption).contentShape(Rectangle()).simultaneousGesture(DragGesture(minimumDistance:40).onEnded {v in if abs(v.translation.width)>abs(v.translation.height)*2 {browsePool(v.translation.width<0 ? 1:-1)}})
            if !pool.collapsed {
                ScrollViewReader {reader in
                    ScrollView(.horizontal,showsIndicators:false) {
                        LazyHStack(spacing:8) {ForEach(pool.projects(library)) {project in
                            Button {if pool.selecting {pool.toggle(project.id)} else {switchPool(project.id)}} label:{
                                ProjectThumbnail(project:project,vault:library.vault,maxDimension:160).frame(width:44,height:48).clipShape(RoundedRectangle(cornerRadius:8))
                                    .overlay(RoundedRectangle(cornerRadius:8).stroke(project.id==pool.state.active ? StudioStyle.blue:Color.clear,lineWidth:2))
                                    .overlay(alignment:.topTrailing) {if pool.state.selected.contains(project.id) {Image(systemName:"checkmark.circle.fill").font(.caption2).foregroundStyle(.white,StudioStyle.blue)}}
                            }.buttonStyle(.plain).disabled(session.busy).accessibilityLabel("Pool item \(project.name)").accessibilityValue(pool.state.selected.contains(project.id) ? "Selected":"Not selected").id(project.id)
                        }}.padding(.horizontal,3).padding(.vertical,3)
                    }.frame(height:54).onAppear {reader.scrollTo(pool.state.active,anchor:.center)}
                }
                if pool.selecting {Text("Tap thumbnails to select; tap the selection button again to browse.").font(.caption2).foregroundStyle(StudioStyle.secondary)}
            }
        }.padding(.horizontal,12).padding(.vertical,4).background(StudioStyle.panel)
    }
    private var header: some View {
        HStack(spacing: 8) {
            Button { Task { if await (pool == nil ? session.persist(library) : session.retire(library)) { dismiss() } else { session.error = library.error ?? "Your edit could not be saved. Keep this screen open and try again." } } } label: { Image(systemName: "chevron.left").frame(width: 44,height: 44) }.accessibilityLabel("Back to workspace")
            VStack(alignment: .leading,spacing: 3) {
                Text(session.project.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(pool?.historyMessage ?? (session.saved ? "ALL CHANGES SAVED" : "SAVING ADJUSTMENTS")).font(.system(size: 8,weight: .medium,design: .monospaced)).tracking(1).foregroundStyle(StudioStyle.secondary)
            }
            Spacer(minLength: 0)
            Button {undoEdit()} label: { Image(systemName: "arrow.uturn.backward").frame(width: 36,height: 44) }.disabled(pool.map {$0.undoHistory.isEmpty || $0.historyBusy} ?? session.undoStack.isEmpty).accessibilityLabel("Undo").keyboardShortcut("z",modifiers:.command)
            Button {undoEdit(redo:true)} label: { Image(systemName: "arrow.uturn.forward").frame(width: 36,height: 44) }.disabled(pool.map {$0.redoHistory.isEmpty || $0.historyBusy} ?? session.redoStack.isEmpty).accessibilityLabel("Redo").keyboardShortcut("z",modifiers:[.command,.shift])
            Button { withAnimation(.easeInOut(duration:0.2)) { controlsHidden.toggle() } } label: { Image(systemName: controlsHidden ? "rectangle.compress.vertical" : "rectangle.expand.vertical").frame(width:36,height:44) }.accessibilityLabel(controlsHidden ? "Show adjustments" : "Expand preview")
            Button { export = true } label: { Image(systemName: "square.and.arrow.up").frame(width: 44,height: 44).background(StudioStyle.blue.opacity(0.16),in: Circle()) }.disabled(session.source == nil).accessibilityLabel(session.project.isVideo ? "Export video" : "Export photo").keyboardShortcut("e",modifiers:.command)
        }.foregroundStyle(.white).padding(.horizontal,10).padding(.vertical,8)
    }
    private var maskViewport:MaskViewport {MaskViewport(scale:min(6,max(1,maskZoom*(tool == .masks ? pinch:1))),offset:CGSize(width:maskOffset.width+(tool == .masks ? drag.width:0),height:maskOffset.height+(tool == .masks ? drag.height:0)))}
    private var previewRecipe:Recipe { tool == .crop && !cropDisplayFinal ? CropEditingGeometry.workspace(session.recipe) : session.recipe }
    private var preview: some View {
        GeometryReader { geometry in
            let sourceSize = session.source.map { PhotoFraming.orientedSize($0.image.extent.size,recipe:session.recipe) } ?? CGSize(width:1,height:1)
            let full = CropEditingGeometry.fit(size:sourceSize,container:geometry.size)
            let raw = CropEditingGeometry.rect(size:sourceSize,recipe:session.recipe)
            let frame = CGRect(x:full.minX+raw.minX*full.width/sourceSize.width,y:full.minY+raw.minY*full.height/sourceSize.height,width:raw.width*full.width/sourceSize.width,height:raw.height*full.height/sourceSize.height)
            let focusScale = min(max(1,geometry.size.width-16)/max(1,frame.width),max(1,geometry.size.height-16)/max(1,frame.height))
            let focusing = tool == .crop && cropFocused
            ZStack {
                StudioStyle.ink
                if let source = session.source {
                    Group {
                        if let video = session.project.video,let url = session.sourceURL {
                            VideoPreview(url:url,descriptor:video,poster:source,recipe:previewRecipe,original:comparing,active:phase == .active && !poolChanging && pool?.historyBusy != true && !poolSync && !poolLookMatch && !poolComparison && !animationSheet && !warpSheet && !referenceSheet && sampleTool == nil && !backgroundSheet && !export && !presets && !versionsSheet && transferSheet == nil && !trimSheet && trackingMask == nil && correctionMask == nil && automaticTarget == nil && peopleMatte == nil && matteReview == nil,onTrim:{ trimSheet = true },scopes:scopesActive ? scopeSampler : nil,split:splitComparison ? splitPosition : nil,maskPreview:maskPreview,hideTransport:isPaintingBrush || tool == .crop,automaticReferenceIDs:session.recipe.masks.compactMap { $0.automatic.map { $0.anchor?.id ?? $0.id } },rangePreview:tool == .color && colorPanel == .selective && showRange ? selectedRange : nil,viewport:tool == .masks ? maskViewport:MaskViewport(),position:videoPosition)
                        } else {
                            LivePreview(source:PhotoRendering.rawPreview(source,recipe:session.recipe),recipe:previewRecipe,signalSource:source.signalImage,original:comparing,rangePreview:tool == .color && colorPanel == .selective && showRange ? selectedRange : nil,active:phase == .active && !poolChanging && pool?.historyBusy != true && !poolSync && !poolLookMatch && !poolComparison && !animationSheet && !warpSheet && !referenceSheet && sampleTool == nil && !export && !presets && !versionsSheet && !retouchSheet && !detailSheet && !backgroundSheet && !photoDevelopment && transferSheet == nil && trackingMask == nil && correctionMask == nil && automaticTarget == nil && peopleMatte == nil && matteReview == nil,hdr:session.recipe.photoHDR == true && !sdrProof,scopes:scopesActive ? scopeSampler : nil,split:splitComparison ? splitPosition : nil,maskPreview:maskPreview).modifier(MaskViewportModifier(viewport:tool == .masks ? maskViewport:MaskViewport()))
                        }
                    }
                        .padding(tool == .crop ? (cropDisplayFinal ? 8 : 22) : 0)
                        .scaleEffect(focusing && !cropDisplayFinal ? focusScale : (tool == .masks ? 1:zoom * pinch)).offset(x: focusing && !cropDisplayFinal ? (geometry.size.width/2-frame.midX)*focusScale : (tool == .masks ? 0:offset.width+drag.width),y: focusing && !cropDisplayFinal ? (geometry.size.height/2-frame.midY)*focusScale : (tool == .masks ? 0:offset.height+drag.height))
                        .gesture(MagnifyGesture().updating($pinch) { value,state,_ in if !splitComparison && tool != .crop && (tool != .masks || maskNavigating) { state = value.magnification } }.onEnded { value in guard !splitComparison && tool != .crop else {return};if tool == .masks {if maskNavigating {maskZoom=min(6,max(1,maskZoom*value.magnification));maskOffset=MaskViewport.bounded(maskOffset,scale:maskZoom,container:geometry.size)};return};zoom = min(4,max(1,zoom * value.magnification)); if zoom == 1 { offset = .zero } })
                        .simultaneousGesture(DragGesture(minimumDistance: 4).updating($drag) { value,state,_ in if tool == .masks {if maskNavigating && maskZoom>1 {state=value.translation}} else if zoom > 1 && tool != .crop { state = value.translation } }.onEnded { value in
                            if tool == .masks {if maskNavigating {maskOffset=MaskViewport.bounded(CGSize(width:maskOffset.width+value.translation.width,height:maskOffset.height+value.translation.height),scale:maskZoom,container:geometry.size)}}
                            else if zoom > 1 && tool != .crop { offset.width += value.translation.width; offset.height += value.translation.height }
                            else if pool != nil && tool != .crop && tool != .masks && !splitComparison && abs(value.translation.width)>70 && abs(value.translation.width)>abs(value.translation.height)*2 {browsePool(value.translation.width<0 ? 1:-1)}
                        })
                        .onTapGesture(count: 2) { guard !splitComparison && tool != .masks && tool != .crop else { return };withAnimation(.easeOut(duration: 0.2)) { zoom = zoom > 1 ? 1 : 2; offset = .zero } }
                        .accessibilityElement(children:.contain)
                        .accessibilityLabel(session.project.isVideo ? "Video preview" : (comparing ? "Original photograph" : "Edited photograph"))
                } else if session.busy { ProgressView("Preparing your media…").font(.caption) }
                else { ContentUnavailableView("Could not open media",systemImage: "photo.badge.exclamationmark",description: Text(session.error ?? "Return to the workspace and try another file.")) }
                if tool == .masks,!comparing,let layer = selectedMask,let source = session.source {
                    if layer.kind == .brush { if isPaintingBrush { BrushMaskCanvas(session:session,id:layer.id,sourceSize:source.image.extent.size,viewport:maskViewport,erase:brushMode == .erase) } }
                    else if !layer.isRange && !layer.kind.isAutomatic && layer.motion == nil { MaskPositionHandle(session:session,id:layer.id,sourceSize:source.image.extent.size,viewport:maskViewport).allowsHitTesting(!maskNavigating) }
                }
                if splitComparison,!comparing,let source = session.source {
                    SplitComparisonDivider(sourceSize:source.image.extent.size,recipe:session.recipe,fraction:$splitPosition)
                }
                if tool == .crop && zoom == 1 && pinch == 1, let source = session.source {
                    CropHandlesOverlay(session:session,sourceSize:source.image.extent.size,editingChanged:{ cropEditing = $0;if $0 { cropAwaitingAdjustment = false } }).opacity(cropFocused ? 0 : 1).allowsHitTesting(!cropFocused)
                }
                if focusing {
                    let visible = CGRect(x:(geometry.size.width-frame.width*focusScale)/2,y:(geometry.size.height-frame.height*focusScale)/2,width:frame.width*focusScale,height:frame.height*focusScale)
                    Path { p in p.addRect(CGRect(origin:.zero,size:geometry.size));p.addRect(visible) }.fill(StudioStyle.ink,style:FillStyle(eoFill:true)).allowsHitTesting(false)
                    VStack { Spacer();HStack { Spacer();Button("Adjust crop",action:resumeCrop).font(.caption.weight(.medium)).padding(10).background(.ultraThinMaterial,in:Capsule()) } }.padding(12).accessibilityIdentifier("cropFittedPreview")
                }
                VStack {
                    HStack {
                        if tool != .masks {Button { inputSheet = true } label: {
                            Text(comparing ? "ORIGINAL" : (session.project.isRAW ? "RAW DEVELOP" : (session.recipe.input.profile == .standard ? (session.recipe.video.hdr ? "INPUT · HDR" : "INPUT · STANDARD") : session.recipe.input.profile.shortTitle+(session.recipe.video.hdr ? " → HDR" : " → SDR"))))
                                .font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1).padding(.horizontal,10).padding(.vertical,7).background(.black.opacity(0.65),in:Capsule())
                        }.disabled(session.project.isRAW).accessibilityLabel("Input conversion")}
                        Spacer()
                        if tool == .masks {
                            HStack(spacing:6) {
                                Button {maskZoom=maskZoom<1.9 ? 2:(maskZoom<3.9 ? 4:1);maskOffset = .zero} label:{Text(maskZoom == 1 ? "Zoom":String(format:"%.0f×",maskZoom))}.accessibilityLabel("Mask preview zoom").accessibilityValue(String(format:"%.0f times",maskZoom)).accessibilityIdentifier("maskPreviewZoom")
                                if maskZoom>1 {Button("Fit"){maskZoom=1;maskOffset = .zero}.accessibilityIdentifier("fitMaskPreview")}
                                if selectedMask?.kind == .brush && selectedMask?.motion == nil || selectedMask.map {!$0.kind.isAutomatic && !$0.isRange && $0.motion==nil} == true {Button(isPaintingBrush ? "Done brushing":(maskNavigating && selectedMask?.kind == .brush && selectedMask?.motion == nil ? "Brush":(maskNavigating ? "Place mask":"Move view"))) {
                                    session.end()
                                    if isPaintingBrush {brushMode = .view;maskNavigating=true}
                                    else if maskNavigating && selectedMask?.kind == .brush && selectedMask?.motion == nil {brushMode = .paint;maskNavigating=false}
                                    else {maskNavigating.toggle()}
                                }.accessibilityIdentifier("maskPreviewInteraction")}
                            }.font(.caption2).padding(8).background(.black.opacity(0.7),in:Capsule())
                        }
                        Button { scopesVisible.toggle() } label: { Label("Scopes",systemImage:"chart.bar.xaxis").foregroundStyle(scopesVisible ? Color.white : StudioStyle.blue).font(.caption2).padding(8).background(scopesVisible ? StudioStyle.blue : Color.black.opacity(0.65),in:Capsule()) }
                    }
                    Spacer()
                    HStack {
                        Menu {
                            if session.project.isVideo {Button("Video animation",systemImage:"diamond"){animationSheet=true}}
                            Button("Color Warp",systemImage:"slider.horizontal.3"){warpSheet=true}
                            Button("Reference & Match",systemImage:"rectangle.split.2x1") {referenceSheet=true}
                            Button("Looks & presets",systemImage:"square.stack") { presets = true }
                            Button("Saved versions",systemImage:"clock.arrow.circlepath") { versionsSheet = true }
                            Divider()
                            Button("Copy adjustments",systemImage:"doc.on.doc") { transferSheet = .copy }
                            Button("Paste adjustments",systemImage:"doc.on.clipboard") { transferSheet = .paste }.disabled(library.adjustmentClipboard == nil)
                        } label: { Label("Looks",systemImage: "square.stack").font(.caption.weight(.medium)).padding(.horizontal,13).padding(.vertical,10).background(.ultraThinMaterial,in: Capsule()) }.disabled(session.source == nil)
                        Spacer()
                        Button { if tool == .masks { tool = .light };splitComparison.toggle();zoom = 1;offset = .zero } label: { Image(systemName:"rectangle.lefthalf.inset.filled").frame(width:36,height:36).background(splitComparison ? StudioStyle.blue : Color.black.opacity(0.6),in:Circle()).foregroundStyle(.white) }.accessibilityLabel("Split before and after").accessibilityValue(splitComparison ? "On" : "Off")
                        Text("Hold to compare").font(.caption).padding(.horizontal,13).padding(.vertical,10).background(.ultraThinMaterial,in: Capsule())
                            .onLongPressGesture(minimumDuration: .infinity,pressing: { comparing = $0 },perform: {})
                            .accessibilityAddTraits(.isButton).accessibilityAction { comparing.toggle() }
                    }.opacity(isPaintingBrush ? 0:1).allowsHitTesting(!isPaintingBrush)
                }.padding(15).opacity(tool == .crop ? 0:1).allowsHitTesting(tool != .crop)
            }.coordinateSpace(name:"comparisonPreview").frame(width: geometry.size.width,height: geometry.size.height).clipped().contentShape(Rectangle())
        }
    }
    private var scopesActive:Bool { scopesVisible && tool != .crop && phase == .active && !poolChanging && pool?.historyBusy != true && !poolSync && !poolLookMatch && !poolComparison && !animationSheet && !warpSheet && !referenceSheet && sampleTool == nil && !export && !presets && !versionsSheet && transferSheet == nil && !trimSheet && trackingMask == nil && correctionMask == nil && automaticTarget == nil && peopleMatte == nil && matteReview == nil && !inputSheet }
    @ViewBuilder private var scopePanel:some View {
        if scopesVisible && tool != .crop { ScopePanel(sampler:scopeSampler,mode:$scopeMode) }
    }
    private var tools: some View {
        HStack(spacing: 0) {
            ForEach(Tool.allCases) { item in
                Button { controlsHidden = false;tool = item; if item == .crop || item == .masks { zoom = 1;offset = .zero };if item == .masks || item == .crop { splitComparison = false } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 18))
                        Text(item.rawValue).font(.system(size: 10,weight: .medium))
                        Circle().fill(StudioStyle.blue).frame(width: 4,height: 4).opacity(session.recipe.hasAdjustments(in: item) ? 1 : 0).accessibilityHidden(true)
                    }
                        .frame(maxWidth: .infinity).frame(height: 60).foregroundStyle(tool == item ? StudioStyle.blue : StudioStyle.secondary)
                        .background(alignment: .bottom) { if tool == item { Capsule().fill(StudioStyle.blue).frame(width: 24,height: 3) } }
                }.buttonStyle(.plain).accessibilityElement(children: .combine).accessibilityValue(session.recipe.hasAdjustments(in: item) ? "Adjustments applied" : "No adjustments").accessibilityAddTraits(tool == item ? .isSelected : [])
            }
        }.background(StudioStyle.panel).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }
    private var controls: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading,spacing: tool == .masks || (tool == .color && (colorPanel == .wheels || colorPanel == .mixer)) ? 12 : 22) {
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
                        Button("Reset entire edit",systemImage: "trash",role: .destructive) { reset = true }
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
                            Button("Remove") { session.change { $0.lut = nil; $0.lutEnabled=nil; $0.lutAmount = 1 } }.font(.caption).padding(.vertical,8)
                        }
                        Text(lut.detail).font(.caption2).foregroundStyle(StudioStyle.secondary)
                        adjustment("LUT strength",key: \.lutAmount,range:0...1,defaultValue:1)
                        Text("A LUT remaps colors for a consistent finish. Strength blends it with your edit; zero turns it off.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }
                    LUTStackControls(session:session)
                    Button { presets = true } label: { Label("Import LUT or save a look",systemImage:"cube.transparent").font(.caption).padding(.vertical,8) }
                    adjustment("Grain",key: \.grain,range: 0...1)
                    if session.recipe.grain>0 {
                        Picker("Grain style",selection:Binding(get:{ session.recipe.grainModel },set:{ value in session.change { $0.grainModel = value } })) { Text("Natural").tag(2);Text("Legacy").tag(1) }.pickerStyle(.segmented)
                        if session.recipe.grainModel == 2 { adjustment("Grain size",key:\.grainSize,range:0...1,defaultValue:0.5) }
                    }
                    adjustment("Halation",key:\.halation,range:0...1)
                    Text("Natural grain follows image brightness. Halation adds a warm glow around strong highlights, while Bloom spreads soft light more broadly. Older grain edits keep Legacy until you switch them.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    adjustment("Bloom",key: \.bloom,range: 0...1)
                    adjustment("Fade",key: \.fade,range: 0...1)
                    adjustment("Vignette",key: \.vignette,range: 0...1)
                case .curves:
                    DisclosureGroup("Levels") {
                        VStack(spacing:18) {
                            Text("Set which tones become black or white. Midtones brightens or darkens the tones between them. Output limits soften the darkest or brightest result.").font(.caption).foregroundStyle(StudioStyle.secondary)
                            HStack {Button("Pick black point",systemImage:"eyedropper"){sampleTool = .blackPoint};Spacer();Button("Pick white point",systemImage:"eyedropper"){sampleTool = .whitePoint}}.font(.caption)
                            adjustment("Input black",key:\.levelBlack,range:0...min(0.95,max(0.01,session.recipe.levelWhite-0.01)))
                            adjustment("Input white",key:\.levelWhite,range:max(0.05,min(0.99,session.recipe.levelBlack+0.01))...1,defaultValue:1)
                            adjustment("Midtones",key:\.levelGamma,range:0.2...3,defaultValue:1)
                            adjustment("Output black",key:\.levelOutputBlack,range:0...min(0.95,max(0.01,session.recipe.levelOutputWhite-0.01)))
                            adjustment("Output white",key:\.levelOutputWhite,range:max(0.05,min(0.99,session.recipe.levelOutputBlack+0.01))...1,defaultValue:1)
                        }.padding(.top,12)
                    }.font(.subheadline)
                    curveControls
                case .masks:
                    maskControls
                case .detail:
                    if !session.project.isVideo {
                        HStack {Button("Photo development",systemImage:"camera.aperture"){photoDevelopment=true};Menu {
                            Button("Heal & Clone",systemImage:"bandage"){retouchSheet=true}
                            Button("Inspect full-resolution detail",systemImage:"viewfinder"){detailSheet=true}
                        } label:{Image(systemName:"ellipsis.circle").font(.title3)}.accessibilityLabel("Photo tools")}.buttonStyle(.bordered)
                    }
                    adjustment("Texture",key:\.texture)
                    adjustment("Clarity",key:\.clarity)
                    adjustment("Dehaze",key:\.dehaze)
                    Text("Dehaze reduces a pale, washed-out veil. Move left to add a soft haze instead. It cannot recover details that were never recorded.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    Text("Move right for more definition; left for a softer image. Texture works on finer detail, while Clarity shapes broader contrast. Neither changes the original.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    adjustment("Sharpen",key: \.sharpen,range: 0...1)
                    adjustment("Noise reduction",key: \.noise,range: 0...1)
                    Text("For fine detail, export at full resolution. Pinch or double-tap the preview to inspect your composition.").font(.caption).foregroundStyle(StudioStyle.secondary)
                case .crop:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))],spacing: 10) {
                        ForEach(Crop.allCases,id: \.self) { crop in
                            Button { session.change { $0.crop = crop; $0.geometry.cropScale = 1 }; zoom = 1; offset = .zero } label: {
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
                    } else {
                        adjustment("Frame size (%)",key:\.geometry.cropScale,range:0.1...1,defaultValue:1)
                    }
                    DisclosureGroup("Lens correction") {
                        adjustment("Lens distortion",key:\.geometry.lensDistortion,range:-0.25...0.25)
                        Text("Straighten barrel or pincushion bending by eye. Edges are kept filled with a small inset when needed. This is manual correction, not an automatic camera/lens profile. Apply it before creating or tracking masks.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }.font(.subheadline)
                    adjustment("Horizontal perspective",key:\.geometry.horizontal,range:-0.3...0.3)
                    adjustment("Vertical perspective",key:\.geometry.vertical,range:-0.3...0.3)
                    adjustment("Straighten",key: \.straighten,range: -15...15,unit: "°")
                    if let source = session.source {
                        let size = PhotoFraming.orientedSize(source.image.extent.size,recipe: session.recipe)
                        let window = PhotoFraming.window(in: size,recipe: session.recipe)
                        if size.width-window.width > 1 { adjustment("Horizontal framing",key: \.cropX,range: 0...1,defaultValue: 0.5) }
                        if size.height-window.height > 1 { adjustment("Vertical framing",key: \.cropY,range: 0...1,defaultValue: 0.5) }
                    }
                    Text("Drag a corner to resize; drag inside to move the frame. Free lets you change width and height independently. This workspace shows the full image with global color; switch tools to review the final crop and local adjustments. Saved automatic selections follow crop changes. After a short pause, the crop smoothly fills the preview; tap Adjust crop to keep framing. Double-tap a slider to reset it.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
            }.padding(20).padding(.bottom,12)
        }.scrollIndicators(.hidden).accessibilityIdentifier("editorAdjustments")
        .onChange(of:automaticRefineExpanded) { _,expanded in
            if expanded { withAnimation(.easeOut(duration:0.2)) { proxy.scrollTo("automaticThreshold",anchor:.top) } }
        }
        }
    }
    private var isPaintingBrush:Bool { tool == .masks && selectedMask?.kind == .brush && selectedMask?.motion == nil && brushMode != .view && !maskNavigating }
    private var selectedMask:LocalMask? { session.recipe.masks.first(where:{ $0.id == selectedMaskID }) ?? session.recipe.masks.first }
    private var maskPreview:LocalMask? { tool == .masks && showMask ? selectedMask : nil }
    private func updateMask(_ change:(inout LocalMask)->Void) {
        guard let layer = selectedMask,let index = session.recipe.masks.firstIndex(where:{ $0.id == layer.id }) else { return }
        session.change { change(&$0.masks[index]) }
    }
    private var maskControls:some View {
        VStack(alignment:.leading,spacing:12) {
            Menu {
                if session.project.isVideo {
                    Button("People video matte"){peopleMatte=PeopleMatteTarget()}.disabled(session.recipe.masks.count>=4)
                    Button("Object video matte"){peopleMatte=PeopleMatteTarget(object:true)}.disabled(session.recipe.masks.count>=4)
                    Button("Remove video background"){peopleMatte=PeopleMatteTarget(cutout:true)}.disabled(session.recipe.masks.count>=4)
                }
                Button("Subject & Background") {automaticTarget=AutomaticSelectionTarget(kind:.subject,maskID:nil,paired:true)}.disabled(session.recipe.masks.count>2)
                ForEach(LocalMaskKind.allCases) { kind in
                    Button(kind.rawValue) {
                        guard session.recipe.masks.count<4 else { return }
                        if kind.isAutomatic { automaticTarget = AutomaticSelectionTarget(kind:kind,maskID:nil);return }
                        var layer = LocalMask(kind:kind);layer = layer.validated();session.change { $0.masks.append(layer) };selectedMaskID = layer.id
                        if kind == .brush {brushMode = .paint;maskNavigating=false};showMask = true
                    }
                }
            } label: { Label("Add mask",systemImage:"plus.circle") }.buttonStyle(.bordered).font(.caption).disabled(session.recipe.masks.count>=4)
            if !session.project.isVideo {
                Button("Remove background",systemImage:"person.crop.rectangle") {removeBackground()}.buttonStyle(.bordered).disabled(session.source == nil || (session.recipe.masks.count>=4 && !session.recipe.masks.contains(where:{$0.kind == .subject && !$0.inverted && $0.automatic?.matches(session.recipe)==true})))
            }
            if session.recipe.hasCutout {Button("Replace background",systemImage:"photo.on.rectangle"){showMask=false;backgroundSheet=true}.buttonStyle(.bordered).accessibilityIdentifier("replaceBackground")}
            if session.recipe.masks.count>2 {Text("Subject & Background needs two free mask slots. Remove a mask to create both regions.").font(.caption).foregroundStyle(StudioStyle.secondary)}
            if let layer = selectedMask {
                if layer.automatic?.temporal != nil {
                    Button("Review & repair matte",systemImage:"paintbrush.pointed"){videoPosition.pause();matteReview=layer}.font(.caption).accessibilityIdentifier("reviewVideoMatte")
                    let object=layer.automatic?.selectionMode == .picked
                    Button(object ? "Rebuild Object video matte":"Rebuild People video matte"){peopleMatte=PeopleMatteTarget(maskID:layer.id,cutout:layer.cutout == true,object:object)}.font(.caption)
                    Toggle("Remove background outside mask",isOn:Binding(get:{layer.cutout == true},set:{value in session.change {r in r.setCutout(layer.id,enabled:value);if value && (r.background == nil || r.background?.mode == .transparent) {r.background=PhotoBackground(mode:.solid)}};if value {showMask=false}})).font(.caption).accessibilityIdentifier("videoMatteCutout")
                }
                Button("Duplicate mask",systemImage:"plus.square.on.square") {
                    var copy=layer;copy.id=UUID();copy.cutout=nil;copy.combination=nil
                    session.change {$0.masks.append(copy)};selectedMaskID=copy.id
                }.font(.caption).disabled(session.recipe.masks.count>=4)
                ScrollView(.horizontal) {
                    HStack { ForEach(Array(session.recipe.masks.enumerated()),id:\.element.id) { index,mask in Button("\(index+1) · \(mask.title)") { selectedMaskID = mask.id }.buttonStyle(.bordered).tint(mask.id == layer.id ? StudioStyle.blue : .gray) } }
                }
                if !session.project.isVideo {
                    Toggle("Keep selection as cutout",isOn:Binding(get:{layer.cutout == true},set:{value in session.change {$0.setCutout(layer.id,enabled:value)};if value {showMask=false}})).font(.caption)
                    if layer.cutout == true {Text("Outside this selection becomes transparent. Refine its edges below; PNG keeps the transparency. Strength blends removal, and Invert keeps the opposite area.").font(.caption2).foregroundStyle(StudioStyle.secondary)}
                }
                if let index = session.recipe.masks.firstIndex(where:{ $0.id == layer.id }),index>0 {
                    Picker("Combine with previous mask",selection:Binding(get:{ layer.combination ?? .independent },set:{ mode in updateMask { $0.combination = mode == .independent ? nil : mode } })) {
                        ForEach(MaskCombination.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu)
                    Text("Uses mask \(index)’s selection. Intersect keeps the overlap; Add includes either area; Subtract removes the previous area. Its adjustment strength and On/off state do not change this selection. Delete a preceding mask and the link follows the new previous mask.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
                if session.project.isVideo && layer.automatic?.temporal == nil && (layer.kind == .radial || layer.kind == .brush || layer.kind == .subject) {
                    HStack {
                        if let motion=layer.motion {
                            Button("Correct tracking",systemImage:"point.topleft.down.to.point.bottomright.curvepath"){correctionMask=layer}.disabled(!motion.matches(session.recipe,duration:session.project.video?.duration ?? 0)).accessibilityIdentifier("correctMaskTracking")
                            Menu("Tracking",systemImage:"ellipsis") {
                                Button("Track again",systemImage:"viewfinder"){if layer.kind == .brush {brushMode = .view};trackingMask=layer}.disabled(layer.kind.isAutomatic && layer.automatic?.matches(session.recipe) != true)
                                Button("Clear tracking",role:.destructive){updateMask {$0.motion=nil}}
                            }
                        } else {
                            Button {if layer.kind == .brush {brushMode = .view};trackingMask=layer} label:{Label("Track mask",systemImage:"viewfinder")}.disabled(layer.kind.isAutomatic && layer.automatic?.matches(session.recipe) != true)
                        }
                    }.buttonStyle(.bordered).font(.caption)
                    if let motion = layer.motion {
                        Text(motion.matches(session.recipe,duration:session.project.video?.duration ?? 0) ? "Tracked position · \(motion.points.count) motion points. Play the clip to review." : "Crop or kept clip changed. Track again or clear tracking before exporting.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }
                }
                if layer.kind == .brush { Picker("Brush tool",selection:$brushMode) { ForEach(BrushInteractionMode.allCases) { mode in Text(mode.rawValue).tag(mode) } }.pickerStyle(.segmented).disabled(layer.motion != nil).onChange(of:brushMode){_,mode in maskNavigating = mode == .view}
                    if layer.motion != nil { Text("Clear tracking before painting more strokes. Strength and local adjustments remain editable.").font(.caption).foregroundStyle(StudioStyle.secondary) }
                }
                HStack {
                    Button { showMask.toggle() } label: { Label("Guide",systemImage:"eye").font(.caption) }.tint(showMask ? StudioStyle.blue : .gray).accessibilityValue(showMask ? "On" : "Off")
                    Button { updateMask { $0.enabled.toggle() } } label: { Label("On",systemImage:"power").font(.caption) }.tint(layer.enabled ? StudioStyle.blue : .gray).accessibilityValue(layer.enabled ? "On" : "Off")
                    Button { updateMask { $0.inverted.toggle() } } label: { Label("Invert",systemImage:"circle.lefthalf.filled").font(.caption) }.tint(layer.inverted ? StudioStyle.blue : .gray).accessibilityValue(layer.inverted ? "On" : "Off")
                }.buttonStyle(.bordered)
                if layer.kind.isAutomatic {
                    if layer.automatic?.temporal == nil {Button("Recreate \(layer.title.lowercased()) selection",systemImage:"arrow.clockwise") { automaticTarget = AutomaticSelectionTarget(kind:layer.kind,maskID:layer.id) }.font(.caption)}
                    if let stored = layer.automatic,!stored.matches(session.recipe) { Text("Updating the selection for the new framing. Export also updates it automatically.").font(.caption).foregroundStyle(StudioStyle.secondary) }
                    DisclosureGroup("Refine automatic selection",isExpanded:$automaticRefineExpanded) {
                        ViewThatFits(in:.horizontal) {
                            HStack {edgePreset("Fine detail",.init(threshold:0.45,transition:1));edgePreset("Clean edge",.init(threshold:0.58,transition:0.65,expand:-0.0004,softness:0.0005));edgePreset("Reset edges",nil)}
                            VStack(alignment:.leading) {edgePreset("Fine detail",.init(threshold:0.45,transition:1));edgePreset("Clean edge",.init(threshold:0.58,transition:0.65,expand:-0.0004,softness:0.0005));edgePreset("Reset edges",nil)}
                        }.buttonStyle(.bordered)
                        Text("Fine detail keeps soft probabilities such as hair. Clean edge tightens the border to reduce spill. These are editable starting points, not new AI analysis; inspect the result over your chosen background. Undo restores the previous edge settings.").font(.caption2).foregroundStyle(StudioStyle.secondary)
                        automaticSlider("Selection threshold",key:\.threshold,range:0.05...0.95).id("automaticThreshold")
                        automaticSlider("Edge transition",key:\.transition,range:0.02...1)
                        automaticSlider("Grow / shrink (%)",key:\.expand,range:-0.01...0.01,scale:100)
                        automaticSlider("Soft edge (%)",key:\.softness,range:0...0.01,scale:100)
                        Text("Threshold changes how certain a pixel must be; transition blends that cutoff. Grow/shrink adjusts the border and soft edge feathers it. Double-tap a slider to restore its default. Use a separate Brush with Intersect/Subtract for manual corrections.").font(.caption2).foregroundStyle(StudioStyle.secondary)
                    }.font(.caption)
                }
                if layer.kind == .color {
                    HStack(spacing:8) {
                        ForEach(Array([0.0,30,60,120,180,240,300].enumerated()),id:\.offset) { _,hue in
                            Button { updateMask { if $0.selection == nil { $0.selection = MaskSelection() };$0.selection?.hue = hue } } label: {
                                Circle().fill(Color(hue:hue/360,saturation:0.9,brightness:0.95)).frame(width:26,height:26).overlay(Circle().stroke(abs((layer.selection?.hue ?? 0)-hue)<1 ? .white : .clear,lineWidth:2))
                            }.accessibilityLabel("Select hue \(Int(hue)) degrees")
                        }
                    }
                    selectionSlider("Color hue (degrees)",key:\.hue,range:0...360)
                    selectionSlider("Color range (degrees)",key:\.tolerance,range:1...180)
                    selectionSlider("Minimum saturation (%)",key:\.minimumSaturation,range:0...1,scale:100)
                    selectionSlider("Soft transition (%)",key:\.softness,range:0.005...0.5,scale:100)
                    Text("Pick a color, then widen Color range to include similar shades. Minimum saturation keeps gray areas out. The red guide shows the selected pixels.").font(.caption).foregroundStyle(StudioStyle.secondary)
                } else if layer.kind == .luminance {
                    HStack {
                        Button("Shadows") { updateMask { $0.selection = MaskSelection(lower:0,upper:0.35) } }
                        Button("Midtones") { updateMask { $0.selection = MaskSelection(lower:0.3,upper:0.7) } }
                        Button("Highlights") { updateMask { $0.selection = MaskSelection(lower:0.65,upper:1) } }
                    }.buttonStyle(.bordered).font(.caption)
                    selectionSlider("Darkest selected (%)",key:\.lower,range:0...1,scale:100)
                    selectionSlider("Brightest selected (%)",key:\.upper,range:0...1,scale:100)
                    selectionSlider("Soft transition (%)",key:\.softness,range:0.005...0.5,scale:100)
                    Text("Select dark, middle or bright areas, then adjust them below. Soft transition blends the edges. Brightness is measured before local adjustments; it is not an exposure meter.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }
                maskSlider("Exposure",key:\.exposure,range:-3...3)
                maskSlider("Warmth",key:\.warmth,range:-1...1)
                maskSlider("Saturation",key:\.saturation,range:-1...1)
                maskSlider("Contrast",key:\.contrast,range:-1...1)
                DisclosureGroup("More local adjustments") {
                    maskSlider("Local tint",key:\.tint,range:-1...1)
                    maskSlider("Local highlights",key:\.highlights,range:-1...1)
                    maskSlider("Local shadows",key:\.shadows,range:-1...1)
                    maskSlider("Local clarity",key:\.clarity,range:-1...1)
                    maskSlider("Local blur",key:\.blur,range:0...1)
                }.font(.subheadline)
                maskSlider("Strength",key:\.amount,range:0...1)
                if layer.kind == .brush {
                    DisclosureGroup("Brush size & soft edge") {
                        maskSlider("Brush radius (%)",key:\.width,range:0.005...0.3,displayScale:100)
                        maskSlider("Soft edge (%)",key:\.feather,range:0.02...1,displayScale:100)
                        Text("Size and softness apply to new strokes. \(layer.brush?.strokes.count ?? 0)/64 strokes; up to 2,048 points per stroke. Lift and start another stroke if it stops extending.").font(.caption2).foregroundStyle(StudioStyle.secondary)
                        Button("Clear painted area",role:.destructive) { updateMask { $0.brush = BrushDrawing() } }
                    }.font(.caption)
                } else if !layer.isRange && !layer.kind.isAutomatic {
                DisclosureGroup("Shape, position & feather") {
                maskSlider("Horizontal position",key:\.centerX,range:0...1)
                maskSlider("Vertical position",key:\.centerY,range:0...1)
                maskSlider(layer.kind == .radial ? "Horizontal radius" : "Gradient width",key:\.width,range:0.03...1)
                if layer.kind == .radial { maskSlider("Vertical radius",key:\.height,range:0.03...1) }
                maskSlider("Rotation",key:\.angle,range:-180...180)
                maskSlider("Feather",key:\.feather,range:0.02...1)
                }.font(.caption)
                }
                Button("Delete selected mask",role:.destructive) { let id = layer.id;session.change { $0.masks.removeAll { $0.id == id } };selectedMaskID = nil }
            }
            Text("Up to four masks. Drag the center in the fitted preview, or use position sliders. Feather softens the edge; invert adjusts the other side. For brush masks, paint directly on the image; View restores preview controls and video scrubbing. Painting pauses video. Size/softness apply to new strokes; undo removes a whole stroke. Masks are anchored to the current crop, stay with this source, and are excluded from reusable looks and copy/paste. Untracked brush and gradient masks stay fixed in video; tracked Radial/Brush masks follow saved position changes. Color and luminance masks select matching pixels in each frame, without object tracking or keyframes. The red guide is never exported.").font(.caption).foregroundStyle(StudioStyle.secondary)
        }
    }
    private func edgePreset(_ title:String,_ refinement:AutomaticRefinement?)->some View {Button(title){updateMask {$0.refinement=refinement}}.accessibilityIdentifier("edgePreset"+title)}
    private func automaticSlider(_ title:String,key:WritableKeyPath<AutomaticRefinement,Double>,range:ClosedRange<Double>,scale:Double = 1) -> some View {
        VStack(spacing:5) {
            HStack { Text(title);Spacer();Text((selectedMask?.refinement ?? AutomaticRefinement())[keyPath:key]*scale,format:.number.precision(.fractionLength(2))).monospacedDigit() }.font(.caption)
            Slider(value:Binding(get:{ (selectedMask?.refinement ?? AutomaticRefinement())[keyPath:key] },set:{ value in
                guard let layer = selectedMask,let index = session.recipe.masks.firstIndex(where:{ $0.id == layer.id }) else { return }
                var r = session.recipe.masks[index].refinement ?? AutomaticRefinement();r[keyPath:key] = value;session.recipe.masks[index].refinement = r
            }),in:range,onEditingChanged:{ $0 ? session.begin() : session.end() }).accessibilityLabel(title).sliderReset { updateMask { var r = $0.refinement ?? AutomaticRefinement();r[keyPath:key] = AutomaticRefinement()[keyPath:key];$0.refinement = r } }
        }
    }
    private func selectionSlider(_ name:String,key:WritableKeyPath<MaskSelection,Double>,range:ClosedRange<Double>,scale:Double = 1) -> some View {
        VStack(spacing:5) {
            HStack { Text(name);Spacer();Text((selectedMask?.selection ?? MaskSelection())[keyPath:key]*scale,format:.number.precision(.fractionLength(1))).monospacedDigit() }.font(.caption)
            Slider(value:Binding(get:{ (selectedMask?.selection ?? MaskSelection())[keyPath:key] },set:{ value in
                guard let layer = selectedMask,let index = session.recipe.masks.firstIndex(where:{ $0.id == layer.id }) else { return }
                var selection = session.recipe.masks[index].selection ?? MaskSelection()
                selection[keyPath:key] = value
                if key == \MaskSelection.lower { selection.upper = max(selection.upper,value) }
                if key == \MaskSelection.upper { selection.lower = min(selection.lower,value) }
                session.recipe.masks[index].selection = selection
            }),in:range,onEditingChanged:{ editing in if editing { session.begin() } else { session.end() } }).tint(StudioStyle.blue)
                .sliderReset { updateMask { SliderDefaults.resetSelection(&$0,key:key) } }
        }
    }
    private func maskSlider(_ name:String,key:WritableKeyPath<LocalMask,Double>,range:ClosedRange<Double>,displayScale:Double = 1) -> some View {
        VStack(spacing:8) {
            HStack { Text(name);Spacer();Text((selectedMask?[keyPath:key] ?? range.lowerBound)*displayScale,format:.number.precision(.fractionLength(2))).monospacedDigit() }.font(.caption)
            Slider(value:Binding(get:{ min(range.upperBound,max(range.lowerBound,selectedMask?[keyPath:key] ?? range.lowerBound)) },set:{ value in
                guard let layer = selectedMask,let index = session.recipe.masks.firstIndex(where:{ $0.id == layer.id }) else { return };session.recipe.masks[index][keyPath:key] = value
            }),in:range,onEditingChanged:{ $0 ? session.begin() : session.end() })
                .accessibilityLabel(name).sliderReset { updateMask { SliderDefaults.reset(&$0,key:key) } }
        }
    }
    private var colorControls: some View {
        VStack(alignment:.leading,spacing: colorPanel == .wheels || colorPanel == .mixer ? 12 : 18) {
            Picker("Color tools",selection:$colorPanel) {
                ForEach(ColorPanel.allCases,id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Button("Color Warp",systemImage:"point.3.connected.trianglepath.dotted"){warpSheet=true}.font(.caption).accessibilityIdentifier("openColorWarp")
            if colorPanel == .global {
                if session.recipe.matchGrade?.isNeutral == false {Button("Reference match active · adjust"){referenceSheet=true}.font(.caption)}
                Button("White balance picker",systemImage:"eyedropper"){sampleTool = .whiteBalance}.font(.caption)
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
            FlexibleCurveControls(session:session,channel:curveChannel)
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
            Slider(value: Binding(get: { session.recipe[keyPath: key] },set: { session.recipe[keyPath: key] = $0 }),in: range,onEditingChanged: { editing in if tool == .crop { cropEditing = editing };if editing { session.begin() } else { session.end() } })
                .accessibilityLabel(name)
                .sliderReset { session.change { $0[keyPath:key] = defaultValue } }
        }
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
        var peakThermal = start
        var thermalSamples:[[String:Any]] = []
        let cleanupCheck=ProcessInfo.processInfo.arguments.contains("--cleanup-performance-check")
        let releaseCheck = ProcessInfo.processInfo.arguments.contains("--release-performance-check")
        let began = CACurrentMediaTime()
        session.recipe.lut = try? await Task.detached(priority:.userInitiated) { try LUTVerification.example(dimension:65) }.value
        session.recipe.levelGamma = 1.1;session.recipe.levelBlack = 0.015;session.recipe.levelWhite = 0.98
        session.recipe.dehaze = 0.25;session.recipe.texture = 0.4;session.recipe.clarity = 0.3
        session.recipe.look = .daylight; session.recipe.grain = 0.15; session.recipe.bloom = 0.1
        session.recipe.straighten = 3; session.recipe.crop = .portrait
        if releaseCheck { session.recipe.halation = 0.15;session.recipe.grainModel = 2;session.recipe.grainSize = 0.4;session.recipe.geometry.lensDistortion = 0.08 }
        let backgroundCheck=ProcessInfo.processInfo.arguments.contains("--background-performance-check")
        let warpCheck=ProcessInfo.processInfo.arguments.contains("--warp-performance-check")
        if warpCheck {var w=ColorWarp();var p=ColorWarpPoint();p.hueShift=20;p.saturationShift=0.15;w.points=[p];session.recipe.colorWarp=w}
        let matchCheck=ProcessInfo.processInfo.arguments.contains("--reference-performance-check")
        if matchCheck {session.recipe.matchGrade=MatchGrade(exposure:0.3,red:1.1,green:0.98,blue:0.9,saturation:1.05)}
        let cutoutCheck=backgroundCheck || ProcessInfo.processInfo.arguments.contains("--cutout-performance-check")
        let inferenceStart=AutomaticSelectionEngine.analysisCount
        if cutoutCheck,let url=session.sourceURL {
            let recipe=session.recipe,prepared=session.source
            do {
                let stored=try await Task.detached(priority:.utility) {
                    let input=try await AutomaticSelectionEngine.input(url:url,video:nil,recipe:recipe,prepared:prepared)
                    return try await AutomaticSelectionEngine.analyze(input,kind:.subject,recipe:recipe,videoStart:nil)
                }.value
                var layer=LocalMask(kind:.subject);layer.automatic=stored;layer.cutout=true;session.recipe.masks=[layer]
                if backgroundCheck {var bg=PhotoBackground();bg.mode = .blur;bg.blur=0.5;session.recipe.background=bg;session.recipe.masks[0].tint=0.1}
                try? await Task.sleep(for:.milliseconds(300));PreviewMetrics.shared.times=[];PreviewMetrics.shared.failures=0
            } catch {writeProgress(["stage":"cutout setup failed","error":error.localizedDescription]);return}
        }
        if cleanupCheck {
            var dabs: [RetouchSpot] = []
            for i in 0..<32 {
                let column = Double(i % 8) * 0.1
                let row = Double(i / 8) * 0.18
                dabs.append(RetouchSpot(x: 0.15 + column, y: 0.2 + row,
                    sourceX: 0.1 + column, sourceY: 0.15 + row, radius: 0.025, kind: .heal))
            }
            session.recipe.retouch = dabs
        }
        let steps = (cutoutCheck || matchCheck || cleanupCheck) ? 1800 : (releaseCheck ? 2700 : (ProcessInfo.processInfo.arguments.contains("--sustained-preview") ? 7200 : 180))
        var interrupted = false
        for index in 0..<steps {
            if Task.isCancelled || UIApplication.shared.applicationState != .active { interrupted = true; break }
            if index % 30 == 0 {
                let thermal = ProcessInfo.processInfo.thermalState.rawValue;peakThermal = max(peakThermal,thermal)
                thermalSamples.append(["seconds":CACurrentMediaTime()-began,"state":thermal,"rendered":PreviewMetrics.shared.times.count])
            }
            if index % 120 == 0 { writeProgress(["stage":"running","step":index,"rendered":PreviewMetrics.shared.times.count,"active":UIApplication.shared.applicationState == .active]) }
            if warpCheck {session.recipe.colorWarp?.amount=0.5+sin(Double(index)*0.09)*0.5}
            if matchCheck {session.recipe.matchGrade?.amount=0.5+sin(Double(index)*0.09)*0.5}
            session.recipe.lutAmount = 0.5 + sin(Double(index)*0.1)*0.5
            session.recipe.levelGamma = 1+sin(Double(index)*0.03)*0.15
            session.recipe.dehaze = sin(Double(index)*0.05)*0.4
            session.recipe.texture = sin(Double(index)*0.08)*0.6;session.recipe.clarity = cos(Double(index)*0.06)*0.4
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
            try? await Task.sleep(for: .milliseconds(releaseCheck ? 33 : 16))
        }
        try? await Task.sleep(for: .seconds(1))
        let count = PreviewMetrics.shared.times.count
        writeProgress(["stage":"idle check","rendered":count])
        for _ in 0..<((cutoutCheck || matchCheck) ? 15 : (releaseCheck ? 30 : 3)) {
            if Task.isCancelled || UIApplication.shared.applicationState != .active { interrupted = true;break }
            peakThermal = max(peakThermal,ProcessInfo.processInfo.thermalState.rawValue)
            try? await Task.sleep(for:.seconds(1))
        }
        let times = PreviewMetrics.shared.times.sorted()
        let report: [String: Any] = ["cleanupDabs":cleanupCheck ? 32:0,"warpCheck":warpCheck,"matchCheck":matchCheck,"backgroundCheck":backgroundCheck,"cutoutCheck":cutoutCheck,"inferenceCalls":AutomaticSelectionEngine.analysisCount-inferenceStart,"cutoutActive":session.recipe.hasCutout,"releaseCheck":releaseCheck,"thermalPeak":peakThermal,"thermalSamples":thermalSamples,"idleCheckSeconds":(cutoutCheck || matchCheck) ? 15:(releaseCheck ? 30 : 3),"interrupted":interrupted,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","elapsedSeconds":CACurrentMediaTime()-began,"cancelled":Task.isCancelled,"requestedUpdates": steps,"rendered": count,"kernelBackend":ColorPipeline.backend,"p95Milliseconds": times.isEmpty ? 0 : times[Int(Double(times.count-1)*0.95)],"extraIdleFrames": times.count-count,"gpuFailures": PreviewMetrics.shared.failures,"thermalStart": start,"thermalEnd": ProcessInfo.processInfo.thermalState.rawValue]
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
