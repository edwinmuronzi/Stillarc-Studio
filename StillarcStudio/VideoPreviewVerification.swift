#if DEBUG
import SwiftUI
import AVFoundation

struct VideoPreviewVerification:View {
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
            if let playback { VideoMetalView(playback:playback,recipe:recipe,original:false,rangePreview:nil,active:phase == .active,scopes:scopeSampler,split:split,maskPreview:recipe.masks.first).frame(maxHeight:.infinity) }
            Text(status).font(.caption.monospaced()).foregroundStyle(StudioStyle.secondary)
            ProgressView(value:progress)
        }.padding(24).background(StudioStyle.ink)
        .task {
            let idle = UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled = true
            defer { scopeSampler.setEnabled(false);UIApplication.shared.isIdleTimerDisabled = idle;playback?.clear() }
            let reportURL = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("video-preview-verification.json")
            do {
                let url = try await Task.detached(priority:.userInitiated) { try await VideoFixtures.make(profile:.appleLog2,frames:300,audioTracks:1,width:1920,height:1080) }.value
                defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
                let descriptor = try await VideoEngine.describe(url)
                try await Task.detached { try ColorPipeline.prepare();try LogConversion.prepare() }.value
                scopeSampler.setEnabled(true)
                let player = VideoPlayback(url:url,descriptor:descriptor);player.looping = true;player.player.isMuted = true;playback = player
                for _ in 0..<100 { if player.ready { break };try await Task.sleep(for:.milliseconds(100)) }
                guard player.ready else { throw StudioError.unreadable }
                recipe.video.hdr = true;recipe.video.start = 0.2;recipe.video.end = 9.8;player.setEdit(recipe.video)
                recipe.input.profile = .appleLog2;recipe.lut = try await Task.detached { try LUTVerification.example(dimension:65) }.value
                var local = LocalMask(kind:.brush);local.exposure = 0.3
                var drawing = BrushDrawing();_ = drawing.begin(point:BrushPoint(x:0.2,y:0.4),radius:0.04,feather:0.6,erase:false);local.brush = drawing
                var sky = LocalMask(kind:.linear);sky.warmth = 0.1;sky.saturation = -0.1
                var accent = LocalMask(kind:.radial);accent.centerX = 0.7;accent.contrast = 0.1
                var foreground = LocalMask(kind:.linear);foreground.inverted = true;foreground.exposure = -0.2
                recipe.masks = [local,sky,accent,foreground]
                recipe.grain = 0.1;recipe.bloom = 0.08;recipe.look = .daylight
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
                let steps = ProcessInfo.processInfo.arguments.contains("--sustained-preview") ? 7200 : 180
                var interrupted = false
                for step in 0..<steps {
                    if Task.isCancelled || UIApplication.shared.applicationState != .active { interrupted = true;break }
                    let point = BrushPoint(x:0.5+sin(Double(step)*0.03)*0.3,y:0.5+cos(Double(step)*0.04)*0.2)
                    if (recipe.masks[0].brush?.strokes.last?.points.count ?? 0)>=2000 { _ = recipe.masks[0].brush?.begin(point:point,radius:0.04,feather:0.6,erase:step%4000>=2000) }
                    else if let id = recipe.masks[0].brush?.strokes.last?.id { recipe.masks[0].brush?.append(point,stroke:id) }
                    split = 0.5+sin(Double(step)*0.05)*0.4
                    recipe.input.exposure = sin(Double(step)*0.04)*0.5
                    recipe.lutAmount = 0.5+sin(Double(step)*0.1)*0.5
                    recipe.exposure = sin(Double(step)*0.08)*0.3
                    recipe.colorWheels.shadows.hue = 220;recipe.colorWheels.shadows.strength = 0.08
                    recipe.channelMixer.redGreen = sin(Double(step)*0.07)*0.04
                    if step % 120 == 0 { status = "Decoded \(player.frameNumber-startFrames) frames · \(step)/\(steps) edits";progress = Double(step)/Double(steps) }
                    try await Task.sleep(for:.milliseconds(16))
                }
                scopeSampler.setEnabled(false)
                player.pause();try await Task.sleep(for:.seconds(1))
                let scopeCount = scopeSampler.completed
                let count = PreviewMetrics.shared.times.count
                try await Task.sleep(for:.seconds(3))
                let times = PreviewMetrics.shared.times.sorted(),idleFrames = times.count-count,decoded = player.frameNumber-startFrames
                let result:[String:Any] = ["passed":!interrupted && decoded>0 && count>0 && idleFrames == 0 && scopeSampler.completed == scopeCount && scopeSampler.completed>0 && PreviewMetrics.shared.failures == 0,"version":"0.12.0","liveBrushPainting":true,"brushRaster":BrushMaskRasterizer.statistics(),"activeMaskLayers":4,"maskGuideVisible":true,"splitComparison":true,"scopesEnabled":true,"scopeJobs":scopeSampler.completed,"scopeJobsAfterHide":scopeSampler.completed-scopeCount,"scopeAnalysisP95Milliseconds":scopeSampler.analysisTimes.sorted().dropFirst(Int(Double(scopeSampler.analysisTimes.count)*0.95)).first ?? 0,"hdrPreview":true,"trimmedPlayback":true,"requestedUpdates":steps,"rendered":count,"decodedFrames":decoded,"elapsedSeconds":CACurrentMediaTime()-began,"p95Milliseconds":times.isEmpty ? 9999 : times[min(times.count-1,Int(Double(times.count)*0.95))],"gpuFailures":PreviewMetrics.shared.failures,"idleFrames":idleFrames,"thermalStart":thermal,"thermalEnd":ProcessInfo.processInfo.thermalState.rawValue,"interrupted":interrupted]
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
