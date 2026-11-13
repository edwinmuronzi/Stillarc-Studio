import SwiftUI

struct PeopleMatteTarget:Identifiable {let id=UUID();var maskID:UUID? = nil;var cutout=false;var object=false;var interval:ClosedRange<Double>? = nil}
struct PeopleVideoMatteSheet:View {
    @Bindable var session:EditSession
    let target:PeopleMatteTarget
    var didSave:(UUID)->Void={_ in}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var image:CGImage?
    @State private var stabilizeEdges=true
    @State private var picked:CGPoint?
    @State private var busy=false
    @State private var progress=0.0
    @State private var message:String?
    @State private var job:Task<AutomaticMask,Error>?
    private var title:String {target.object ? "Object video matte":"People video matte"}
    var body:some View {
        NavigationStack {GeometryReader {geometry in
            let wide=geometry.size.width>geometry.size.height*1.3
            let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
            layout {
                if let image {
                    GeometryReader {g in
                        let fit=MaskViewport().rect(size:CGSize(width:image.width,height:image.height),container:g.size)
                        Image(decorative:image,scale:1).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity)
                        if target.object {
                            Color.clear.contentShape(Rectangle()).gesture(SpatialTapGesture().onEnded {v in
                                if !busy,fit.contains(v.location) {picked=CGPoint(x:(v.location.x-fit.minX)/fit.width,y:(v.location.y-fit.minY)/fit.height);message=nil}
                            }).accessibilityLabel("Tap inside the object to follow").accessibilityIdentifier("objectVideoPickPreview")
                            if let picked {Image(systemName:"scope").font(.title).foregroundStyle(.white).shadow(radius:3).position(x:fit.minX+picked.x*fit.width,y:fit.minY+picked.y*fit.height).allowsHitTesting(false)}
                        }
                    }.frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:18)).padding(12)
                } else {ProgressView("Preparing first kept frame…").frame(maxWidth:.infinity,maxHeight:.infinity)}
                ScrollView {VStack(alignment:.leading,spacing:12) {
                    Text(target.object ? "Tap an object. Follow its outline.":(target.cutout ? "Keep people. Replace the scene.":"Follow a changing silhouette.")).font(.headline)
                    Text(target.object ? "Tap inside a distinct foreground object on this full-frame preview. Studio follows its location and creates a fresh outline for every kept frame, then saves the masks for smooth playback. Your export still uses its chosen crop. Preparation stops if the object is lost or the match becomes ambiguous; it does not guess through occlusions. Review fine edges, reflections and fast movement.":"Processes every kept video frame once using on-device People matting, then reuses the saved masks during playback and export. All visible people are included. Review hair, fast movement and occlusions; this is not perfect roto.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    Text("Up to 15 seconds, 900 source frames and 48 MB of saved mattes. This allows 15 seconds at 30 or 60 fps; detailed clips can reach the storage limit sooner. No source frames are skipped. People mattes are bounded to 1536 pixels and object analysis to 1024 pixels on the longest edge. Video export keeps its chosen dimensions. Cancellation, backgrounding or cooling leaves previous edits unchanged.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    Toggle("Stabilize moving edges",isOn:$stabilizeEdges).disabled(busy).font(.caption)
                    Text("Uses neighbouring frames and image detail during preparation to reduce contour flashes. Rebuild existing mattes to apply it. Turn it off if a difficult fast-moving edge looks softened.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    if let interval=target.interval {Text(String(format:"Reanalyse only %.2f–%.2f s. Frames outside this section and manual repairs are preserved.",interval.lowerBound,interval.upperBound)).font(.caption).foregroundStyle(StudioStyle.blue)}
                    if target.cutout {Text("Starts with a solid background. Use Replace background afterward for a colour, image or blur. Transparent video-file export is not supported.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    else {Text("After preparation, enable Remove background outside mask to keep this subject and replace the scene.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    if busy {
                        ProgressView(value:progress)
                        Text("Preparing frame mattes… \(Int(progress*100))%").font(.caption.monospacedDigit())
                        Text("The new matte is saved only when every kept frame is ready.").font(.caption).foregroundStyle(StudioStyle.secondary)
                        Button("Cancel processing",role:.cancel){job?.cancel()}.buttonStyle(.bordered).accessibilityIdentifier("cancelPeopleVideoMatte")
                    }
                    if let message {Text(message).font(.caption).foregroundStyle(.orange)}
                    Button(busy ? "Processing…":"Prepare & save video matte",systemImage:target.object ? "viewfinder":"person.crop.rectangle") {create()}.buttonStyle(.borderedProminent).disabled(busy || image==nil || (target.object && picked==nil)).accessibilityIdentifier("preparePeopleVideoMatte")
                }.padding(18)}.frame(width:wide ? min(340,geometry.size.width*0.42):nil).frame(maxHeight:wide ? .infinity:280).background(StudioStyle.panel)
            }
        }.background(StudioStyle.ink).navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar {Button(busy ? "Cancel":"Done"){job?.cancel();dismiss()}.accessibilityIdentifier("closeVideoMattePreparation")}}.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .task {
            guard let url=session.sourceURL else {return}
            var r=session.recipe;if target.object {r.reset(.crop)};if let interval=target.interval {let margin=2/max(1,session.project.video?.frameRate ?? 30);r.video.start=max(0,interval.lowerBound-margin);r.video.end=min(session.project.video?.duration ?? interval.upperBound,interval.upperBound+margin)}
            let captured=r,video=session.project.video
            do {let worker=Task.detached(priority:.utility){try await AutomaticSelectionEngine.input(url:url,video:video,recipe:captured)};let loaded=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});if !Task.isCancelled {image=loaded}} catch {if !Task.isCancelled {message=error.localizedDescription}}
        }.onDisappear {job?.cancel()}.onChange(of:phase){_,value in if value != .active {job?.cancel();message="Processing stopped when Studio left the foreground. Previous edits are unchanged; prepare again when ready."}}
    }
    private func create() {
        guard !busy,let url=session.sourceURL,let video=session.project.video,(!target.object || picked != nil) else {return}
        let captured=session.recipe,point=target.object ? picked:nil,stable=stabilizeEdges
        var processing=captured;if let interval=target.interval {let margin=2/max(1,video.frameRate);processing.video.start=max(0,interval.lowerBound-margin);processing.video.end=min(video.duration,interval.upperBound+margin)};let work=processing
        busy=true;progress=0;message=nil
        let worker=Task.detached(priority:.utility) {try await PeopleVideoMatte.analyze(url:url,descriptor:video,recipe:work,objectPoint:point,stabilizeEdges:stable){value in await MainActor.run {progress=value}}};job=worker
        Task { @MainActor in
            defer {busy=false;job=nil}
            do {
                var stored=try await worker.value
                guard !worker.isCancelled,phase == .active,session.recipe==captured else {return}
                if target.interval != nil {
                    guard let interval=target.interval,let old=captured.masks.first(where:{$0.id==target.maskID})?.automatic,let original=old.temporal,let analysed=stored.temporal,let merged=original.replacing(analysed,interval:interval) else {throw AutomaticSelectionEngine.error("The repaired section could not be merged safely. Existing matte is unchanged.")}
                    stored=old;stored.temporal=merged
                }
                var next=captured,id=target.maskID
                if let old=target.maskID,let i=next.masks.firstIndex(where:{$0.id==old}) {next.masks[i].automatic=stored;next.masks[i].motion=nil;next.masks[i].label=title;if let interval=target.interval {next.masks[i].videoRepairs?.dismissedHints.removeAll {$0>=interval.lowerBound && $0<interval.upperBound}}}
                else {guard next.masks.count<4 else {return};var layer=LocalMask(kind:.subject);layer.label=title;layer.automatic=stored;layer.cutout=target.cutout ? true:nil;id=layer.id;next.masks.append(layer)}
                if let id,target.cutout {next.setCutout(id,enabled:true);if next.background == nil || next.background?.mode == .transparent {next.background=PhotoBackground(mode:.solid)}}
                session.change {$0=next};if let id {didSave(id)};dismiss()
            } catch is CancellationError {message="Processing cancelled. Previous edits are unchanged."} catch {message=error.localizedDescription}
        }
    }
}
