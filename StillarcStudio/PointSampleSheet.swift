import SwiftUI

struct PointSampleSheet:View {
    @Bindable var session:EditSession
    let tool:PointSampleTool
    var initialTime=0.0
    var undoAction:()->Void={}
    var redoAction:()->Void={}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var photo:PreparedPhoto?
    @State private var frameTime=0.0
    @State private var point:CGPoint?
    @State private var busy=false
    @State private var message:String?
    @State private var failure:String?
    @State private var operation=UUID()
    @State private var work:Task<Void,Never>?
    var body:some View {
        NavigationStack {
            GeometryReader {geometry in
                let wide=geometry.size.width>geometry.size.height*1.3
                let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
                layout {
                GeometryReader {g in
                    if let photo {
                        let size=PhotoFraming.apply(photo.image,recipe:session.recipe).extent.size
                        let fit=CropEditingGeometry.fit(size:size,container:g.size)
                        ZStack {
                            LivePreview(source:PhotoRendering.rawPreview(photo,recipe:session.recipe),recipe:session.recipe,signalSource:photo.signalImage,original:false,active:phase == .active,hdr:session.project.isVideo ? session.recipe.video.hdr:session.recipe.photoHDR == true,stillFrame:session.project.isVideo ? .init(time:frameTime,framing:MaskMotion.signature(session.recipe)):nil)
                            if let point {Circle().stroke(.white,lineWidth:2).background(Circle().stroke(.black.opacity(0.7),lineWidth:4)).frame(width:24,height:24).position(x:fit.minX+fit.width*point.x,y:fit.minY+fit.height*point.y).allowsHitTesting(false)}
                            Color.clear.contentShape(Rectangle()).gesture(SpatialTapGesture().onEnded {v in
                                guard fit.contains(v.location),!busy else {return}
                                let p=CGPoint(x:(v.location.x-fit.minX)/fit.width,y:(v.location.y-fit.minY)/fit.height)
                                sample(p)
                            }).accessibilityIdentifier("pointSamplePreview").accessibilityLabel("Tap an area to sample")
                        }.clipShape(RoundedRectangle(cornerRadius:18))
                    } else {ProgressView("Preparing preview…").frame(maxWidth:.infinity,maxHeight:.infinity)}
                }.padding(12)
                ScrollView {VStack(alignment:.leading,spacing:12) {
                    Text(tool == .whiteBalance ? "Tap something that should be neutral grey or white. Warmth and Tint will adjust together.":"Tap an area to make it the \(tool == .blackPoint ? "black":"white") point. A small patch is averaged to avoid picking just one noisy pixel.").font(.subheadline)
                    Text("Sampling uses the underlying image before \(tool == .whiteBalance ? "white balance":"Levels"), with your crop and input conversion. Looks, local masks, repairs and replacement backgrounds do not influence the measurement. Their effects remain visible in this preview.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    if session.project.isVideo {Text("Video uses the frame where you opened the picker. The adjustment applies to the whole clip.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    if busy {ProgressView("Sampling…")}
                    if let message {Text(message).font(.caption).foregroundStyle(StudioStyle.blue).accessibilityIdentifier("pointSampleResult")}
                    if let failure {Text(failure).font(.caption).foregroundStyle(.orange)}
                    Button(tool == .whiteBalance ? "Reset white balance":"Reset Levels",systemImage:"arrow.counterclockwise") {
                        session.change {r in if tool == .whiteBalance {r.warmth=0;r.tint=0} else {r.levelBlack=0;r.levelWhite=1;r.levelGamma=1;r.levelOutputBlack=0;r.levelOutputWhite=1}}
                        message=nil;failure=nil
                    }.font(.caption).disabled(busy)
                }.padding(18)}.frame(width:wide ? min(340,geometry.size.width*0.42):nil).frame(maxHeight:wide ? .infinity:280).background(StudioStyle.panel)
                }
            }.background(StudioStyle.ink).navigationTitle(tool.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement:.topBarLeading) {
                        Button(action:undoAction){Image(systemName:"arrow.uturn.backward")}.accessibilityLabel("Undo sampled adjustment").disabled(busy)
                        Button(action:redoAction){Image(systemName:"arrow.uturn.forward")}.accessibilityLabel("Redo sampled adjustment").disabled(busy)
                    }
                    ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}}
                }
        }.tint(StudioStyle.blue)
            .task {await load()}
            .onDisappear {cancel()}
            .onChange(of:phase){_,value in if value != .active {cancel()}}
    }
    private func cancel() {operation=UUID();work?.cancel();work=nil;busy=false}
    private func load() async {
        guard let video=session.project.video,let url=session.sourceURL else {photo=session.source;return}
        frameTime=min(session.recipe.video.range(duration:video.duration).upperBound,max(session.recipe.video.range(duration:video.duration).lowerBound,initialTime))
        do {
            let time=frameTime
            let worker=Task.detached(priority:.utility){try await VideoEngine.poster(url,descriptor:video,maxDimension:1536,time:time)}
            let loaded=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
            if !Task.isCancelled {photo=loaded}
        } catch {if !Task.isCancelled {failure=error.localizedDescription}}
    }
    private func sample(_ point:CGPoint) {
        guard let photo,!busy,phase == .active else {return}
        session.end();busy=true;message=nil;failure=nil;self.point=point
        let id=UUID();operation=id
        let captured=session.recipe,time=frameTime,isVideo=session.project.isVideo
        work=Task {
            defer {if operation==id {busy=false;work=nil}}
            do {
                let worker=Task.detached(priority:.userInitiated) {
                    try Task.checkCancellation()
                    let r=VideoAnimation.resolve(captured,time:isVideo ? time:nil)
                    let raw=PhotoRendering.rawPreview(photo,recipe:r)
                    let source=r.input.profile == .standard ? raw:(photo.signalImage ?? raw)
                    let input=PointSampling.reference(source,recipe:r,stage:tool.stage,hdr:isVideo ? r.video.hdr:r.photoHDR == true)
                    let mean=PointSampling.mean(input,point:point)
                    return try PointSampling.solve(mean,tool:tool,recipe:r)
                }
                let result=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
                guard !Task.isCancelled,operation==id,session.recipe==captured else {return}
                session.change {PointSampling.apply(result,to:&$0)}
                message=tool == .whiteBalance ? "White balance updated. Undo restores both controls.":"\(tool == .blackPoint ? "Black":"White") point updated. Undo restores the previous point."
            } catch is CancellationError {} catch {if !Task.isCancelled,operation==id {failure=error.localizedDescription}}
        }
    }
}
