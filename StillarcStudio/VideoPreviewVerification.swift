#if DEBUG
import SwiftUI
import AVFoundation
import CoreImage

struct VideoPreviewVerification:View {
    private var animationCheck:Bool {ProcessInfo.processInfo.arguments.contains("--animation-performance-check") || ProcessInfo.processInfo.arguments.contains("--correction-performance-check") || ProcessInfo.processInfo.arguments.contains("--precision-performance-check")}
    @State private var viewport=MaskViewport()
    @State private var playback:VideoPlayback?
    @State private var recipe = Recipe()
    @State private var scopeSampler = ScopeSampler()
    @State private var split = 0.5
    @State private var status = "Preparing private video fixture…"
    @State private var progress = 0.0
    @Environment(\.scenePhase) private var phase
    var body:some View {
        VStack(spacing:16) {
            Text("Studio Log/video preview check").font(.headline)
            if let playback { VideoMetalView(playback:playback,recipe:recipe,original:false,rangePreview:nil,active:phase == .active,scopes:scopeSampler,split:split,maskPreview:animationCheck ? nil:recipe.masks.dropFirst().first).modifier(MaskViewportModifier(viewport:viewport)).frame(maxHeight:.infinity) }
            Text(status).font(.caption.monospaced()).foregroundStyle(StudioStyle.secondary)
            ProgressView(value:progress)
        }.padding(24).background(StudioStyle.ink)
        .task {
            let idle = UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled = true
            defer { scopeSampler.setEnabled(false);UIApplication.shared.isIdleTimerDisabled = idle;playback?.clear() }
            if ProcessInfo.processInfo.arguments.contains("--precision-performance-check") {
                let fixture=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("MaskPersonQA.png")
                if FileManager.default.fileExists(atPath:fixture.path) {try? FileManager.default.removeItem(at:fixture)}
            }
            let reportURL = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("video-preview-verification.json")
            do {
                let url = try await Task.detached(priority:.userInitiated) { try await VideoFixtures.make(profile:.appleLog2,frames:300,audioTracks:1,width:1920,height:1080) }.value
                defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
                let descriptor = try await VideoEngine.describe(url)
                try await Task.detached { try ColorPipeline.prepare();try LogConversion.prepare() }.value
                scopeSampler.setEnabled(!animationCheck)
                let player = VideoPlayback(url:url,descriptor:descriptor);player.looping = true;player.player.isMuted = true;playback = player
                for _ in 0..<100 { if player.ready { break };try await Task.sleep(for:.milliseconds(100)) }
                guard player.ready else { throw StudioError.unreadable }
                recipe.video.hdr = true;recipe.video.start = 0.2;recipe.video.end = 9.8;player.setEdit(recipe.video)
                recipe.input.profile = .appleLog2;recipe.lut = try await Task.detached { try CombinedLUTVerification.example(one:4096,three:65) }.value
                recipe.lutLayers=[LUTLayer(asset:try await Task.detached {try OneDLUTVerification.example(dimension:4096)}.value,amount:0.2),LUTLayer(asset:recipe.lut!,amount:0.15)]
                for channel in CurveChannel.allCases {recipe.rgbCurves[keyPath:channel.key].nodes=[CurveNode(x:0,y:0.01),CurveNode(x:0.12,y:0.08),CurveNode(x:0.55,y:0.6),CurveNode(x:1,y:0.99)]}
                var local = LocalMask(kind:.brush);local.exposure = 0.3
                var drawing = BrushDrawing();_ = drawing.begin(point:BrushPoint(x:0.2,y:0.4),radius:0.04,feather:0.6,erase:false);local.brush = drawing
                var sky = LocalMask(kind:.color);sky.combination = .intersect;sky.warmth = 0.1;sky.saturation = -0.1
                var accent = LocalMask(kind:.luminance);accent.combination = .add;accent.centerX = 0.7;accent.contrast = 0.1
                var foreground = LocalMask(kind:.sky);foreground.combination = .subtract;foreground.exposure = -0.2
                let autoExtent = CGRect(x:0,y:0,width:1280,height:720)
                let autoShape = CIFilter(name:"CILinearGradient",parameters:["inputPoint0":CIVector(x:0,y:250),"inputPoint1":CIVector(x:0,y:500),"inputColor0":CIColor.black,"inputColor1":CIColor.white])!.outputImage!.cropped(to:autoExtent)
                foreground.automatic = try AutomaticMaskBitmap.make(autoShape,recipe:recipe,videoStart:recipe.video.start);foreground.refinement = AutomaticRefinement()
                if let matte=foreground.automatic {
                    foreground.automatic?.anchor=AutomaticMaskAnchor(id:matte.id,png:matte.png,width:matte.width,height:matte.height,framing:matte.framing)
                }
                foreground.motion=MaskMotion(framing:MaskMotion.signature(recipe),start:0,end:10,points:[.init(time:0,x:0,y:0),.init(time:10,x:0.02,y:0)],pivotX:0.5,pivotY:0.5,sourceWidth:1920,sourceHeight:1080)
                foreground.motion?.setCorrection(time:0,x:0,y:0,tolerance:0.001,scale:1,rotation:0)
                foreground.motion?.correctionBlend = .smooth
                foreground.motion?.setCorrection(time:5,x:0,y:0,tolerance:0.001,scale:1.4,rotation:35)
                foreground.motion?.setCorrection(time:10,x:0,y:0,tolerance:0.001,scale:1,rotation:0)
                recipe.masks = [local,sky,accent,foreground]
                recipe.masks[0].motion = MaskMotion(framing:MaskMotion.signature(recipe),start:0,end:10,points:[.init(time:0,x:0,y:0),.init(time:5,x:0.15,y:-0.1),.init(time:10,x:0,y:0)])
                if ProcessInfo.processInfo.arguments.contains("--correction-performance-check") {
                    for t in stride(from:0.0,through:10.0,by:1.0) {recipe.masks[0].motion?.setCorrection(time:t,x:sin(t)*0.04,y:cos(t)*0.03,tolerance:0.001)}
                }
                recipe.grain = 0.1;recipe.bloom = 0.08;recipe.look = .daylight
                recipe.masks[0].motion?.setCorrection(time:0,x:0,y:0,tolerance:0.001,scale:1,rotation:0)
                recipe.masks[0].motion?.setCorrection(time:5,x:0.05,y:0,tolerance:0.001,scale:1.6,rotation:60)
                recipe.masks[0].motion?.setCorrection(time:10,x:0,y:0,tolerance:0.001,scale:1,rotation:0)
                if animationCheck {
                    func track(_ target:AnimationTarget,_ a:Double,_ b:Double)->AnimationTrack {var t=AnimationTrack(target:target);t.points=[AnimationPoint(time:0.2,value:a),AnimationPoint(time:5,value:b),AnimationPoint(time:9.7,value:a)];return t}
                    recipe.videoAnimation=VideoAnimation(tracks:[track(.exposure,-0.25,0.25),track(.look,0.3,1),track(.lut,1,0.4),track(.mask(local.id),0.2,1)])
                }
                player.toggle();try await Task.sleep(for:.seconds(1))
                guard let frame = player.frame else { throw StudioError.unreadable }
                let pair = VideoEngine.images(frame,descriptor:descriptor,maxDimension:1280)
                var inputOnly = Recipe();inputOnly.input.profile = .appleLog2
                let image = ImageEngine.apply(pair.signal,recipe:inputOnly)
                let average = image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:image.extent.insetBy(dx:4,dy:4))])
                var pixels = [Float](repeating:0,count:4)
                ImageEngine.context().render(average,toBitmap:&pixels,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
                let reference = CameraLogProfile.appleLog2.matrix.map { row in zip(row,VideoFixtures.scene).map(*).reduce(0,+) }.map { v in v <= 0.0031308 ? v*12.92 : 1.055*pow(v,1/2.4)-0.055 }
                guard (0..<3).allSatisfy({ abs(Double(pixels[$0])-reference[$0])<0.025 }) else { throw NSError(domain:"StudioVideoPreview",code:1,userInfo:[NSLocalizedDescriptionKey:"Playback Log decoding differs from export: \(pixels)"]) }
                PreviewMetrics.shared.times = [];PreviewMetrics.shared.failures = 0
                let began = CACurrentMediaTime(),thermal = ProcessInfo.processInfo.thermalState.rawValue,startFrames = player.frameNumber
                let inferenceBefore = AutomaticSelectionEngine.analysisCount
                let steps = animationCheck ? 1800 : ProcessInfo.processInfo.arguments.contains("--sustained-preview") ? 7200 : 180
                var peakThermal=thermal
                var interrupted = false
                for step in 0..<steps {
                    if Task.isCancelled || UIApplication.shared.applicationState != .active { interrupted = true;break }
                    if !animationCheck {
                    let point = BrushPoint(x:0.5+sin(Double(step)*0.03)*0.3,y:0.5+cos(Double(step)*0.04)*0.2)
                    if (recipe.masks[0].brush?.strokes.last?.points.count ?? 0)>=2000 { _ = recipe.masks[0].brush?.begin(point:point,radius:0.04,feather:0.6,erase:step%4000>=2000) }
                    else if let id = recipe.masks[0].brush?.strokes.last?.id { recipe.masks[0].brush?.append(point,stroke:id) }
                    recipe.masks[1].selection?.hue = Double(step%360);recipe.masks[2].selection?.upper = 0.6+sin(Double(step)*0.04)*0.3
                    recipe.masks[3].refinement?.threshold = 0.5+sin(Double(step)*0.03)*0.1
                    split = 0.5+sin(Double(step)*0.05)*0.4
                    recipe.input.exposure = sin(Double(step)*0.04)*0.5
                    recipe.lutAmount = 0.5+sin(Double(step)*0.1)*0.5
                    recipe.exposure = sin(Double(step)*0.08)*0.3
                    recipe.colorWheels.shadows.hue = 220;recipe.colorWheels.shadows.strength = 0.08
                    recipe.channelMixer.redGreen = sin(Double(step)*0.07)*0.04
                    }
                    if ProcessInfo.processInfo.arguments.contains("--precision-performance-check"),step % 30 == 0 {viewport=MaskViewport(scale:Double([1,2,4][(step/30)%3]),offset:CGSize(width:sin(Double(step))*40,height:cos(Double(step))*20))}
                    if step % 30 == 0 {peakThermal=max(peakThermal,ProcessInfo.processInfo.thermalState.rawValue)}
                    if step % 120 == 0 { status = "Decoded \(player.frameNumber-startFrames) frames · \(step)/\(steps) edits";progress = Double(step)/Double(steps) }
                    try await Task.sleep(for:.milliseconds(animationCheck ? 33:16))
                }
                scopeSampler.setEnabled(false)
                player.pause();try await Task.sleep(for:.seconds(1))
                let scopeCount = scopeSampler.completed
                let count = PreviewMetrics.shared.times.count
                try await Task.sleep(for:.seconds(3))
                let times = PreviewMetrics.shared.times.sorted(),idleFrames = times.count-count,decoded = player.frameNumber-startFrames
                let result:[String:Any] = ["maskSizeRotation":true,"posedAutomaticAnchor":true,"lutLayers":3,"oneDLUTPoints":4096,"flexibleCurveChannels":4,"analysisCallsDuringPlayback":AutomaticSelectionEngine.analysisCount-inferenceBefore,"cachedAutomaticMask":true,"passed":AutomaticSelectionEngine.analysisCount == inferenceBefore && !interrupted && decoded>0 && count>0 && idleFrames == 0 && scopeSampler.completed == scopeCount && (animationCheck || scopeSampler.completed>0) && PreviewMetrics.shared.failures == 0,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","animationCheck":animationCheck,"privatePortraitFixtureRemoved":!FileManager.default.fileExists(atPath:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("MaskPersonQA.png").path),"zoomedMaskPreview":ProcessInfo.processInfo.arguments.contains("--precision-performance-check"),"trackingCorrections":ProcessInfo.processInfo.arguments.contains("--correction-performance-check"),"trackedMaskPlayback":true,"maskCombinations":true,"colorAndLuminanceMasks":true,"liveBrushPainting":!animationCheck,"brushRaster":BrushMaskRasterizer.statistics(),"activeMaskLayers":4,"maskGuideVisible":!animationCheck,"splitComparison":true,"scopesEnabled":!animationCheck,"scopeJobs":scopeSampler.completed,"scopeJobsAfterHide":scopeSampler.completed-scopeCount,"scopeAnalysisP95Milliseconds":scopeSampler.analysisTimes.sorted().dropFirst(Int(Double(scopeSampler.analysisTimes.count)*0.95)).first ?? 0,"hdrPreview":true,"trimmedPlayback":true,"requestedUpdates":steps,"rendered":count,"decodedFrames":decoded,"elapsedSeconds":CACurrentMediaTime()-began,"p95Milliseconds":times.isEmpty ? 9999 : times[min(times.count-1,Int(Double(times.count)*0.95))],"gpuFailures":PreviewMetrics.shared.failures,"idleFrames":idleFrames,"thermalPeak":peakThermal,"thermalStart":thermal,"thermalEnd":ProcessInfo.processInfo.thermalState.rawValue,"interrupted":interrupted]
                try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:reportURL,options:.atomic)
                status = "Video preview check complete";progress = 1
            } catch {
                let result:[String:Any] = ["passed":false,"error":error.localizedDescription]
                if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:reportURL,options:.atomic) }
                status = error.localizedDescription
            }
        }
        .onDisappear { playback?.clear() }
    }
}
#endif
