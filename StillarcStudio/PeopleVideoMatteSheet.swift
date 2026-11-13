import SwiftUI

struct PeopleMatteTarget:Identifiable {let id=UUID();var maskID:UUID? = nil;var cutout=false}
struct PeopleVideoMatteSheet:View {
    @Bindable var session:EditSession
    let target:PeopleMatteTarget
    var didSave:(UUID)->Void={_ in}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var image:CGImage?
    @State private var busy=false
    @State private var progress=0.0
    @State private var message:String?
    @State private var job:Task<AutomaticMask,Error>?
    var body:some View {
        NavigationStack {GeometryReader {geometry in
            let wide=geometry.size.width>geometry.size.height*1.3
            let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
            layout {
            if let image {Image(decorative:image,scale:1).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:18)).padding(12)}
            else {ProgressView("Preparing first kept frame…").frame(maxWidth:.infinity,maxHeight:.infinity)}
            ScrollView {VStack(alignment:.leading,spacing:12) {
                Text(target.cutout ? "Keep people. Replace the scene.":"Follow a changing silhouette.").font(.headline)
                Text("Processes every kept video frame once using on-device People matting, then reuses the saved masks during playback and export. All visible people are included. Saved matte resolution is bounded to 1536 pixels on its longest edge; video output keeps its chosen resolution. Review hair, fast movement and occlusions; this is not perfect roto or general object segmentation.").font(.caption).foregroundStyle(StudioStyle.secondary)
                Text("Up to 12 seconds, 360 source frames and 16 MB of saved mattes. Shorten the kept clip first. No frames are skipped to fit the budget. Processing stops if cancelled, interrupted or too hot, leaving the previous edit unchanged.").font(.caption).foregroundStyle(StudioStyle.secondary)
                if target.cutout {Text("Starts with a solid background. Use Replace background afterward for a colour, image or blur. Transparent video-file export is not supported.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                if busy {
                    ProgressView(value:progress)
                    Text("Preparing frame mattes… \(Int(progress*100))%").font(.caption.monospacedDigit())
                    Text("You can cancel safely. The new matte is saved only when every kept frame is ready.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    Button("Cancel processing",role:.cancel){job?.cancel()}.buttonStyle(.bordered).accessibilityIdentifier("cancelPeopleVideoMatte")
                }
                if let message {Text(message).font(.caption).foregroundStyle(.orange)}
                Button(busy ? "Processing…":"Prepare & save video matte",systemImage:"person.crop.rectangle") {create()}.buttonStyle(.borderedProminent).disabled(busy || image==nil).accessibilityIdentifier("preparePeopleVideoMatte")
            }.padding(18)}.frame(width:wide ? min(340,geometry.size.width*0.42):nil).frame(maxHeight:wide ? .infinity:280).background(StudioStyle.panel)
            }
        }.background(StudioStyle.ink).navigationTitle("People video matte").navigationBarTitleDisplayMode(.inline).toolbar {Button(busy ? "Cancel":"Done"){job?.cancel();dismiss()}}}.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .task {
            guard let url=session.sourceURL else {return}
            let r=session.recipe,video=session.project.video
            do {let worker=Task.detached(priority:.utility){try await AutomaticSelectionEngine.input(url:url,video:video,recipe:r)};let loaded=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});if !Task.isCancelled {image=loaded}} catch {if !Task.isCancelled {message=error.localizedDescription}}
        }.onDisappear {job?.cancel()}.onChange(of:phase){_,value in if value != .active {job?.cancel();message="Processing stopped when Studio left the foreground. Previous edits are unchanged; prepare again when ready."}}
    }
    private func create() {
        guard !busy,let url=session.sourceURL,let video=session.project.video else {return}
        let captured=session.recipe;busy=true;progress=0;message=nil
        let worker=Task.detached(priority:.utility) {try await PeopleVideoMatte.analyze(url:url,descriptor:video,recipe:captured){value in await MainActor.run {progress=value}}};job=worker
        Task { @MainActor in
            defer {busy=false;job=nil}
            do {
                let stored=try await worker.value
                guard !worker.isCancelled,phase == .active,session.recipe==captured else {return}
                var next=captured,id=target.maskID
                if let old=target.maskID,let i=next.masks.firstIndex(where:{$0.id==old}) {next.masks[i].automatic=stored;next.masks[i].motion=nil;next.masks[i].label="People video matte"}
                else {guard next.masks.count<4 else {return};var layer=LocalMask(kind:.subject);layer.label="People video matte";layer.automatic=stored;layer.cutout=target.cutout ? true:nil;id=layer.id;next.masks.append(layer)}
                if let id,target.cutout {next.setCutout(id,enabled:true);next.background=PhotoBackground(mode:.solid)}
                session.change {$0=next};if let id {didSave(id)};dismiss()
            } catch is CancellationError {message="Processing cancelled. Previous edits are unchanged."} catch {message=error.localizedDescription}
        }
    }
}
