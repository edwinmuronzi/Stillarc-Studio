import SwiftUI
import AVFoundation
import MetalKit
import CoreImage

@MainActor @Observable final class VideoPlayback {
    let player = AVPlayer()
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes:VideoEngine.pixelAttributes)
    let descriptor:VideoDescriptor
    var looping = false
    var playing = false
    var time = 0.0
    var ready = false
    var error:String?
    var frame:CVPixelBuffer?
    var frameNumber = 0
    var active = true
    private var resume = false
    private var link:CADisplayLink?
    private var initialTicks = 0
    private var endObserver:NSObjectProtocol?
    private var statusObserver:NSKeyValueObservation?
    private var seeking = false
    private var pendingSeek:Double?
    private var resumeAfterScrub = false
    private var observedItem:AVPlayerItem?
    init(url:URL,descriptor:VideoDescriptor) {
        self.descriptor = descriptor
        player.automaticallyWaitsToMinimizeStalling = false
        let item = AVPlayerItem(url:url);item.preferredForwardBufferDuration = 0.2; observedItem = item
        output.suppressesPlayerRendering = true
        item.add(output);player.replaceCurrentItem(with:item)
        statusObserver = item.observe(\.status,options:[.initial,.new]) { [weak self] item,_ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.status == .readyToPlay { self.ready = true; self.requestFrame() }
                if item.status == .failed { self.error = item.error?.localizedDescription ?? "This video couldn’t be opened." }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName:.AVPlayerItemDidPlayToEndTime,object:item,queue:.main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.looping && self.active { self.seek(0);self.playing = true;self.player.play();self.startLink() }
                else { self.pause() }
            }
        }
    }
    @MainActor private final class Target:NSObject {
        weak var owner:VideoPlayback?
        init(_ owner:VideoPlayback) { self.owner = owner }
        @objc func tick() { owner?.tick() }
    }
    private func startLink() {
        guard link == nil,active else { return }
        let link = CADisplayLink(target:Target(self),selector:#selector(Target.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum:15,maximum:30,preferred:30)
        link.add(to:.main,forMode:.common); self.link = link
    }
    private func requestFrame() { initialTicks = 0;startLink() }
    private func tick() {
        guard active else { stopLink(); return }
        let now = player.currentTime()
        if now.isNumeric, output.hasNewPixelBuffer(forItemTime:now),let buffer = output.copyPixelBuffer(forItemTime:now,itemTimeForDisplay:nil) {
            frame = buffer;frameNumber += 1;initialTicks = 0
            if now.seconds.isFinite && abs(time-now.seconds)>0.1 && !seeking { time = now.seconds }
            if !playing && !seeking { stopLink() }
        } else if !playing && !seeking {
            initialTicks += 1
            if initialTicks > 60 { stopLink() }
        }
    }
    func toggle() {
        if playing { pause();return }
        guard ready,active else { return }
        if time >= descriptor.duration-0.05 { seek(0) }
        playing = true;player.play();startLink()
    }
    func pause() { player.pause();playing = false;stopLink() }
    private func stopLink() { link?.invalidate();link = nil }
    func setActive(_ value:Bool) {
        guard value != active else { return };active = value
        if !value { resume = playing;pause() }
        else { requestFrame();if resume { resume = false;playing = true;player.play();startLink() } }
    }
    func beginScrub() { resumeAfterScrub = playing;pause() }
    func endScrub() { if resumeAfterScrub { resumeAfterScrub = false;playing = true;player.play();startLink() } }
    func seek(_ seconds:Double) {
        time = min(descriptor.duration,max(0,seconds));pendingSeek = time
        advanceSeek()
    }
    private func advanceSeek() {
        guard !seeking,let seconds = pendingSeek else { return }
        pendingSeek = nil;seeking = true
        player.seek(to:CMTime(seconds:seconds,preferredTimescale:600),toleranceBefore:CMTime(value:1,timescale:30),toleranceAfter:CMTime(value:1,timescale:30)) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return };self.seeking = false;self.requestFrame();self.advanceSeek()
            }
        }
    }
    func clear() {
        pause();statusObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) };endObserver = nil
        if let item = observedItem { item.remove(output) };observedItem = nil
        player.replaceCurrentItem(with:nil);frame = nil
    }
}

struct VideoPreview:View {
    let url:URL;let descriptor:VideoDescriptor;let poster:PreparedPhoto;let recipe:Recipe;let original:Bool;let active:Bool
    var rangePreview:ColorRange?
    @State private var playback:VideoPlayback?
    var body:some View {
        Group {
            if let playback { VideoPreviewContent(playback:playback,poster:poster,recipe:recipe,original:original,active:active,rangePreview:rangePreview) }
            else { LivePreview(source:poster.image,recipe:recipe,signalSource:poster.signalImage,original:original,active:active) }
        }
        .task { if playback == nil { let controller = VideoPlayback(url:url,descriptor:descriptor);controller.setActive(active);playback = controller } }
        .onChange(of:active) { _,value in playback?.setActive(value) }
        .onDisappear { playback?.clear();playback = nil }
    }
}
private struct VideoPreviewContent:View {
    @Bindable var playback:VideoPlayback
    let poster:PreparedPhoto;let recipe:Recipe;let original:Bool;let active:Bool;let rangePreview:ColorRange?
    var body:some View {
        ZStack(alignment:.bottom) {
            VideoMetalView(playback:playback,recipe:recipe,original:original,rangePreview:rangePreview,active:active)
            if playback.frame == nil { LivePreview(source:poster.image,recipe:recipe,signalSource:poster.signalImage,original:original,active:active) }
            HStack(spacing:12) {
                Button { playback.toggle() } label: { Image(systemName:playback.playing ? "pause.fill" : "play.fill").frame(width:36,height:36) }.disabled(!playback.ready).accessibilityLabel(playback.playing ? "Pause video" : "Play video")
                Slider(value:Binding(get:{ playback.time },set:{ playback.seek($0) }),in:0...max(0.01,playback.descriptor.duration),onEditingChanged:{ $0 ? playback.beginScrub() : playback.endScrub() }).accessibilityLabel("Video position")
                Text("\(Int(playback.time))/\(Int(playback.descriptor.duration))s").font(.caption2.monospacedDigit()).fixedSize()
            }.padding(.horizontal,10).background(.ultraThinMaterial,in:Capsule()).padding(.horizontal,16).padding(.bottom,62)
            if let error = playback.error { Text(error).font(.caption).padding().background(.black.opacity(0.8)).frame(maxHeight:.infinity,alignment:.center) }
        }
    }
}

struct VideoMetalView:UIViewRepresentable {
    @Bindable var playback:VideoPlayback
    let recipe:Recipe;let original:Bool;let rangePreview:ColorRange?;let active:Bool
    func makeCoordinator() -> Renderer { Renderer() }
    func makeUIView(context:Context) -> MTKView {
        let view = MTKView(frame:.zero,device:context.coordinator.device)
        view.isPaused = true;view.enableSetNeedsDisplay = true;view.framebufferOnly = false;view.colorPixelFormat = .bgra8Unorm
        view.contentScaleFactor = min(view.traitCollection.displayScale,2)
        (view.layer as? CAMetalLayer)?.colorspace = ImageEngine.output
        view.delegate = context.coordinator;return view
    }
    func updateUIView(_ view:MTKView,context:Context) {
        _ = playback.frameNumber
        context.coordinator.update(buffer:playback.frame,descriptor:playback.descriptor,recipe:recipe,original:original,range:rangePreview,active:active,view:view)
    }
    static func dismantleUIView(_ view:MTKView,coordinator:Renderer) { view.delegate = nil;coordinator.clear() }
    @MainActor final class Renderer:NSObject,MTKViewDelegate {
        let device = MTLCreateSystemDefaultDevice()
        lazy var commands = device?.makeCommandQueue()
        lazy var context = device.map { CIContext(mtlDevice:$0,options:[.workingColorSpace:ImageEngine.working,.cacheIntermediates:false]) }
        private var buffer:CVPixelBuffer?
        private var descriptor:VideoDescriptor?
        private var recipe = Recipe(), original = false, active = true, dirty = true, drawing = false
        private var range:ColorRange?
        func clear() { buffer = nil;context?.clearCaches() }
        func update(buffer:CVPixelBuffer?,descriptor:VideoDescriptor,recipe:Recipe,original:Bool,range:ColorRange?,active:Bool,view:MTKView) {
            guard self.buffer !== buffer || self.recipe != recipe || self.original != original || self.range != range || self.active != active else { return }
            self.buffer = buffer;self.descriptor = descriptor;self.recipe = recipe;self.original = original;self.range = range;self.active = active;dirty = true
            if active && !drawing { view.setNeedsDisplay() }
        }
        func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) { dirty = true;if active && !drawing { view.setNeedsDisplay() } }
        func draw(in view:MTKView) {
            guard dirty,active,!drawing,let buffer,let descriptor,let context,let command = commands?.makeCommandBuffer(),let drawable = view.currentDrawable else { return }
            let size = view.drawableSize;guard size.width>0 && size.height>0 else { return }
            drawing = true;dirty = false
            let began = CACurrentMediaTime()
            let pair = VideoEngine.images(buffer,descriptor:descriptor,maxDimension:1280)
            var comparison = Recipe();comparison.copyFraming(from:recipe)
            let selected = original ? comparison : recipe
            let source = selected.input.profile == .standard ? pair.managed : pair.signal
            let image = ImageEngine.apply(source,recipe:selected,rangePreview:original ? nil : range)
            let scale = min(size.width/image.extent.width,size.height/image.extent.height)
            let placed = image.transformed(by:.init(scaleX:scale,y:scale)).transformed(by:.init(translationX:(size.width-image.extent.width*scale)/2,y:(size.height-image.extent.height*scale)/2))
            let background = CIImage(color:CIColor(red:0.025,green:0.03,blue:0.04)).cropped(to:CGRect(origin:.zero,size:size))
            context.render(placed.composited(over:background),to:drawable.texture,commandBuffer:command,bounds:CGRect(origin:.zero,size:size),colorSpace:ImageEngine.output)
            command.addCompletedHandler { [weak self,weak view] completed in
                withExtendedLifetime(buffer) {}
                let ms = (CACurrentMediaTime()-began)*1000
                DispatchQueue.main.async {
                    #if DEBUG
                    PreviewMetrics.shared.record(ms:ms,failed:completed.status == .error)
                    #endif
                    guard let self,let view else { return };self.drawing = false
                    if self.dirty && self.active { view.setNeedsDisplay() }
                }
            }
            command.present(drawable);command.commit()
        }
    }
}
