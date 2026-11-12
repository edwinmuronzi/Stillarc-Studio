import SwiftUI
import AVFoundation
import MetalKit
import CoreImage

@MainActor @Observable final class VideoPlayback {
    #if DEBUG
    static var creationCount = 0
    #endif
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
    var frameTime = 0.0
    var selection:ClosedRange<Double> { edit.range(duration:descriptor.duration) }
    var edit = VideoEdit()
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
        #if DEBUG
        Self.creationCount += 1
        #endif
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
                if self.looping && self.active { self.seek(self.selection.lowerBound);self.playing = true;self.player.play();self.startLink() }
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
        if playing && !seeking && now.isNumeric && now.seconds >= selection.upperBound {
            if looping { seek(selection.lowerBound);player.play() }
            else { pause();time = selection.upperBound }
        }
        var displayTime = CMTime.invalid
        if now.isNumeric, output.hasNewPixelBuffer(forItemTime:now),let buffer = output.copyPixelBuffer(forItemTime:now,itemTimeForDisplay:&displayTime) {
            frameTime = displayTime.isNumeric ? displayTime.seconds : now.seconds
            frame = buffer;frameNumber += 1;initialTicks = 0
            if now.seconds.isFinite && abs(time-now.seconds)>0.1 && !seeking { time = min(selection.upperBound,max(selection.lowerBound,now.seconds)) }
            if !playing && !seeking { stopLink() }
        } else if !playing && !seeking {
            initialTicks += 1
            if initialTicks > 60 { stopLink() }
        }
    }
    func toggle() {
        if playing { pause();return }
        guard ready,active else { return }
        if time >= selection.upperBound-0.001 || time < selection.lowerBound { seek(selection.lowerBound) }
        playing = true;player.play();startLink()
    }
    func pause() { player.pause();playing = false;stopLink() }
    private func stopLink() { link?.invalidate();link = nil }
    func setActive(_ value:Bool) {
        guard value != active else { return };active = value
        if !value { resume = playing;pause() }
        else { if time < selection.lowerBound || time >= selection.upperBound { seek(selection.lowerBound) };requestFrame();if resume { resume = false;playing = true;player.play();startLink() } }
    }
    func setEdit(_ value:VideoEdit) {
        guard edit != value else { return };let previous = edit;edit = value
        guard active else { return }
        if previous.start != value.start || previous.end != value.end {
            pause()
            seek(previous.start != value.start ? selection.lowerBound : max(selection.lowerBound,selection.upperBound-1/max(1,descriptor.frameRate)))
        } else if time < selection.lowerBound || time >= selection.upperBound { seek(selection.lowerBound) }
    }
    func showAutomaticReferenceFrame() {
        resume = false;resumeAfterScrub = false;pause();seek(selection.lowerBound)
    }
    func beginScrub() { resumeAfterScrub = playing;pause() }
    func endScrub() { if resumeAfterScrub && active { resumeAfterScrub = false;playing = true;player.play();startLink() } }
    func seek(_ seconds:Double) {
        time = min(selection.upperBound,max(selection.lowerBound,seconds));pendingSeek = time
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
    var onTrim:() -> Void = {}
    var showTrimButton = true
    var scopes:ScopeSampler? = nil
    var split:Double? = nil
    var maskPreview:LocalMask? = nil
    var hideTransport = false
    var automaticReferenceIDs:[UUID]? = nil
    var rangePreview:ColorRange?
    var viewport=MaskViewport()
    var position:ClipPosition? = nil
    @State private var playback:VideoPlayback?
    var body:some View {
        Group {
            if let playback { VideoPreviewContent(playback:playback,poster:poster,recipe:recipe,original:original,active:active,onTrim:onTrim,showTrimButton:showTrimButton,scopes:scopes,split:split,maskPreview:maskPreview,hideTransport:hideTransport,rangePreview:rangePreview,automaticReferenceIDs:automaticReferenceIDs ?? recipe.masks.compactMap { $0.automatic?.id },viewport:viewport,position:position) }
            else { LivePreview(source:poster.image,recipe:recipe,signalSource:poster.signalImage,original:original,active:active,hdr:recipe.video.hdr,split:split,maskPreview:maskPreview).modifier(MaskViewportModifier(viewport:viewport)) }
        }
        .task { if playback == nil { let controller = VideoPlayback(url:url,descriptor:descriptor);controller.setEdit(recipe.video);if let position {controller.seek(position.time)};controller.setActive(active);playback = controller } }
        .onChange(of:active) { _,value in playback?.setActive(value) }
        .onChange(of:hideTransport) { _,value in if value { playback?.pause() } }
        .onChange(of:recipe.video) { _,value in playback?.setEdit(value) }
        .onDisappear { playback?.clear();playback = nil }
    }
}
private struct VideoPreviewContent:View {
    @Bindable var playback:VideoPlayback
    let poster:PreparedPhoto;let recipe:Recipe;let original:Bool;let active:Bool;let onTrim:() -> Void;let showTrimButton:Bool;let scopes:ScopeSampler?;let split:Double?;let maskPreview:LocalMask?;let hideTransport:Bool;let rangePreview:ColorRange?;let automaticReferenceIDs:[UUID]
    var viewport=MaskViewport()
    var position:ClipPosition? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transportVisible = false
    @State private var scrubbing = false
    @State private var transportRevision = 0
    var body:some View {
        ZStack(alignment:.bottom) {
            VideoMetalView(playback:playback,recipe:recipe,original:original,rangePreview:rangePreview,active:active,scopes:scopes,split:split,maskPreview:maskPreview).modifier(MaskViewportModifier(viewport:viewport))
            if playback.frame == nil { LivePreview(source:poster.image,recipe:recipe,signalSource:poster.signalImage,original:original,active:active,hdr:recipe.video.hdr,split:split,maskPreview:maskPreview).modifier(MaskViewportModifier(viewport:viewport)) }
            Color.clear.contentShape(Rectangle()).onTapGesture { guard !hideTransport else { return };withAnimation(.easeInOut(duration:reduceMotion ? 0.12 : 0.28)) { transportVisible.toggle() };transportRevision += 1 }.accessibilityIdentifier("playbackReveal").accessibilityLabel("Show playback controls").accessibilityAddTraits(.isButton).accessibilityAction { transportVisible = true;transportRevision += 1 }
            if !hideTransport && transportVisible {
            HStack(spacing:12) {
                Button { playback.toggle();transportRevision += 1 } label: { Image(systemName:playback.playing ? "pause.fill" : "play.fill").frame(width:36,height:36) }.disabled(!playback.ready).accessibilityLabel(playback.playing ? "Pause video" : "Play video")
                if showTrimButton { Button(action:onTrim) { Image(systemName:"scissors").frame(width:32,height:36) }.accessibilityLabel("Trim video") }
                Slider(value:Binding(get:{ playback.time },set:{ playback.seek($0) }),in:playback.selection,onEditingChanged:{ scrubbing = $0;transportRevision += 1;$0 ? playback.beginScrub() : playback.endScrub() }).accessibilityLabel("Video position").sliderReset { playback.beginScrub();playback.seek(playback.selection.lowerBound);playback.endScrub() }
                Text("\(Int(playback.time))/\(Int(playback.descriptor.duration))s").font(.caption2.monospacedDigit()).fixedSize()
            }.padding(.horizontal,10).background(.ultraThinMaterial,in:Capsule()).padding(.horizontal,16).padding(.bottom,showTrimButton ? 62 : 12).transition(.opacity).allowsHitTesting(transportVisible && !hideTransport)
            }
            if let error = playback.error { Text(error).font(.caption).padding().background(.black.opacity(0.8)).frame(maxHeight:.infinity,alignment:.center) }
        }.animation(.easeInOut(duration:reduceMotion ? 0.12 : 0.28),value:transportVisible)
        .animation(.easeInOut(duration:reduceMotion ? 0.12 : 0.28),value:hideTransport)
        .task(id:"\(transportVisible)|\(scrubbing)|\(transportRevision)") {
            guard transportVisible,!scrubbing else { return }
            do { try await Task.sleep(for:.seconds(3));withAnimation(.easeInOut(duration:reduceMotion ? 0.12 : 0.28)) { transportVisible = false } } catch {}
        }.onChange(of:hideTransport) { _,value in transportVisible = !value;transportRevision += 1 }
        .onAppear {position?.time=playback.time;position?.playing=playback.playing}
        .onChange(of:playback.time){_,value in position?.time=value}
        .onChange(of:playback.frameTime){_,value in if !playback.playing {position?.time=value}}
        .onChange(of:playback.playing){_,value in position?.playing=value;if !value {position?.time=playback.frameTime}}
        .onChange(of:position?.seekToken){_,_ in if let position {playback.beginScrub();playback.seek(position.time);playback.endScrub()}}
        .onChange(of:position?.pauseToken){_,_ in playback.pause()}
        .onChange(of:automaticReferenceIDs) { old,new in
            if new.contains(where:{ !old.contains($0) }) { playback.showAutomaticReferenceFrame() }
        }
    }
}

private final class VideoFrameLease: @unchecked Sendable {
    let buffer:CVPixelBuffer
    init(_ buffer:CVPixelBuffer) { self.buffer = buffer }
}

struct VideoMetalView:UIViewRepresentable {
    @Bindable var playback:VideoPlayback
    let recipe:Recipe;let original:Bool;let rangePreview:ColorRange?;let active:Bool
    var scopes:ScopeSampler? = nil
    var split:Double? = nil
    var maskPreview:LocalMask? = nil
    func makeCoordinator() -> Renderer { Renderer() }
    func makeUIView(context:Context) -> MTKView {
        let view = MTKView(frame:.zero,device:context.coordinator.device)
        view.isPaused = true;view.enableSetNeedsDisplay = true;view.framebufferOnly = false;view.colorPixelFormat = .rgba16Float
        view.contentScaleFactor = min(view.traitCollection.displayScale,2)
        (view.layer as? CAMetalLayer)?.colorspace = ImageEngine.working
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
        context.coordinator.watchBrush(view)
        view.delegate = context.coordinator;return view
    }
    func updateUIView(_ view:MTKView,context:Context) {
        _ = playback.frameNumber
        (view.layer as? CAMetalLayer)?.colorspace = recipe.video.hdr ? ImageEngine.working : ImageEngine.output
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = recipe.video.hdr
        context.coordinator.update(buffer:playback.frame,frameTime:playback.frameTime,descriptor:playback.descriptor,recipe:recipe,original:original,range:rangePreview,active:active,scopes:scopes,split:split,maskPreview:maskPreview,view:view)
    }
    static func dismantleUIView(_ view:MTKView,coordinator:Renderer) { view.delegate = nil;coordinator.clear() }
    @MainActor final class Renderer:NSObject,MTKViewDelegate {
        let device = MTLCreateSystemDefaultDevice()
        lazy var commands = device?.makeCommandQueue()
        lazy var context = device.map { CIContext(mtlDevice:$0,options:[.workingColorSpace:ImageEngine.working,.cacheIntermediates:false]) }
        private var frameTime = 0.0
        private var buffer:CVPixelBuffer?
        private var descriptor:VideoDescriptor?
        private var recipe = Recipe(), original = false, active = true, dirty = true, drawing = false
        private var scopes:ScopeSampler?
        private var split:Double?
        private var maskPreview:LocalMask?
        private var range:ColorRange?
        private var brushObserver:NSObjectProtocol?
        func watchBrush(_ view:MTKView) {
            brushObserver = NotificationCenter.default.addObserver(forName:.studioBrushReady,object:nil,queue:.main) { [weak self,weak view] note in
                guard let id = note.object as? UUID else { return }
                Task { @MainActor [weak self,weak view] in
                    guard let self,let view,self.active,self.recipe.masks.contains(where:{ $0.brush?.id == id || $0.automatic?.id == id }) else { return };self.dirty = true;if !self.drawing { view.setNeedsDisplay() }
                }
            }
        }
        func clear() { if let brushObserver { NotificationCenter.default.removeObserver(brushObserver) };brushObserver = nil;buffer = nil;context?.clearCaches() }
        func update(buffer:CVPixelBuffer?,frameTime:Double,descriptor:VideoDescriptor,recipe:Recipe,original:Bool,range:ColorRange?,active:Bool,scopes:ScopeSampler?,split:Double?,maskPreview:LocalMask?,view:MTKView) {
            guard self.frameTime != frameTime || self.buffer !== buffer || self.recipe != recipe || self.original != original || self.range != range || self.active != active || self.scopes !== scopes || self.split != split || self.maskPreview != maskPreview else { return }
            self.frameTime = frameTime;self.buffer = buffer;self.descriptor = descriptor;self.recipe = recipe;self.original = original;self.range = range;self.active = active;self.scopes = scopes;self.split = split;self.maskPreview = maskPreview;dirty = true
            if active && !drawing { view.setNeedsDisplay() }
        }
        func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) { dirty = true;if active && !drawing { view.setNeedsDisplay() } }
        func draw(in view:MTKView) {
            guard dirty,active,!drawing,let buffer,let descriptor,let context,let command = commands?.makeCommandBuffer(),let drawable = view.currentDrawable else { return }
            let size = view.drawableSize;guard size.width>0 && size.height>0 else { return }
            drawing = true;dirty = false
            let began = CACurrentMediaTime()
            let pair = VideoEngine.images(buffer,descriptor:descriptor,maxDimension:1280)
            let image = MaskMotion.$frame.withValue(MaskMotion.Frame(time:frameTime,framing:MaskMotion.signature(recipe))) {
                var comparison = Recipe();comparison.copyFraming(from:recipe)
                let selected = VideoAnimation.resolve(original ? comparison : recipe,time:frameTime)
                let source = selected.input.profile == .standard ? pair.managed : pair.signal
                var image = HDRPipeline.grade(source,recipe:selected,hdr:recipe.video.hdr,rangePreview:original ? nil : range,preview:true)
                if !original,let split {
                    let before = HDRPipeline.grade(pair.managed,recipe:comparison,hdr:recipe.video.hdr)
                    image = ComparisonRender.combine(original:before,edited:image,fraction:split)
                }
                if !recipe.video.hdr { image = image.applyingFilter("CIColorClamp",parameters:["inputMinComponents":CIVector(x:0,y:0,z:0,w:0),"inputMaxComponents":CIVector(x:1,y:1,z:1,w:1)]) }
                scopes?.offer(image,hdr:recipe.video.hdr)
                if !original {
                    var reference:CIImage? = nil
                    if maskPreview != nil && recipe.masks.contains(where:{ $0.isRange }) {
                        reference = HDRPipeline.maskReference(source,recipe:selected,hdr:recipe.video.hdr)
                    }
                    image = MaskEngine.overlay(image,layer:maskPreview.flatMap {preview in selected.masks.first(where:{$0.id==preview.id})},reference:reference,layers:selected.masks,framing:MaskMotion.signature(recipe))
                }
                return image
            }
            let scale = min(size.width/image.extent.width,size.height/image.extent.height)
            let placed = image.transformed(by:.init(scaleX:scale,y:scale)).transformed(by:.init(translationX:(size.width-image.extent.width*scale)/2,y:(size.height-image.extent.height*scale)/2))
            let background = CIImage(color:CIColor(red:0.025,green:0.03,blue:0.04)).cropped(to:CGRect(origin:.zero,size:size))
            context.render(placed.composited(over:background),to:drawable.texture,commandBuffer:command,bounds:CGRect(origin:.zero,size:size),colorSpace:recipe.video.hdr ? ImageEngine.working : ImageEngine.output)
            let lease = VideoFrameLease(buffer)
            command.addCompletedHandler { [weak self,weak view] completed in
                withExtendedLifetime(lease) {}
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
