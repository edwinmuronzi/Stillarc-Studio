import SwiftUI
import PhotosUI
import CoreImage

@MainActor struct ReferenceMatchSheet:View {
    @Bindable var session:EditSession
    @Bindable var library:StudioLibrary
    var pool:EditingPool? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var picker:PhotosPickerItem?
    @State private var files=false
    @State private var busy=false
    @State private var error:String?
    @State private var message:String?
    @State private var reference:CIImage?
    @State private var referenceCG:CGImage?
    @State private var current:PreparedPhoto?
    @State private var light=true
    @State private var color=true
    @State private var richness=false
    private var grade:MatchGrade {session.recipe.matchGrade ?? MatchGrade()}
    private var previewRecipe:Recipe {var r=session.recipe;if session.project.isVideo {r.photoHDR=r.video.hdr};return r}
    private var firstTime:Double {session.project.video.map {session.recipe.video.range(duration:$0.duration).lowerBound} ?? 0}
    private var currentFrame:MaskMotion.Frame? {session.project.isVideo ? .init(time:firstTime,framing:MaskMotion.signature(session.recipe)):nil}
    private var candidates:[Project] {Array((pool?.projects(library) ?? library.projects).filter {$0.id != session.project.id}.prefix(20))}
    var body:some View {
        NavigationStack {VStack(spacing:0) {
            GeometryReader {g in
                if g.size.width>g.size.height*1.4 {HStack(spacing:12) {referencePane;currentPane}.padding(12)}
                else {VStack(spacing:10) {referencePane;currentPane}.padding(12)}
            }.frame(maxWidth:.infinity,maxHeight:.infinity).background(StudioStyle.ink)
            ScrollView {VStack(alignment:.leading,spacing:14) {
                HStack {
                    PhotosPicker(selection:$picker,matching:.images,preferredItemEncoding:.current) {Label("Photos",systemImage:"photo")}
                    Button("Files",systemImage:"folder"){files=true}
                    Menu("From projects",systemImage:"rectangle.stack") {ForEach(candidates) {p in Button(p.name){Task {await fromProject(p)}}}}.disabled(candidates.isEmpty)
                }.buttonStyle(.bordered).font(.caption).disabled(busy)
                if session.recipe.reference != nil {
                    HStack {Toggle("Light",isOn:$light);Toggle("Color balance",isOn:$color);Toggle("Richness",isOn:$richness)}.font(.caption).toggleStyle(.button).buttonStyle(.bordered).disabled(busy)
                    Button("Suggest a match",systemImage:"wand.and.stars") {Task {await suggest()}}.buttonStyle(.borderedProminent).disabled(busy || reference == nil || current == nil || (!light && !color && !richness)).accessibilityIdentifier("suggestReferenceMatch")
                }
                if session.recipe.matchGrade != nil {
                    HStack {Text("Match strength");Spacer();Text(grade.amount,format:.percent.precision(.fractionLength(0))).monospacedDigit()}.font(.caption)
                    Slider(value:Binding(get:{grade.amount},set:{v in var g=grade;g.amount=v;session.recipe.matchGrade=g}),in:0...1,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel("Match strength").sliderReset {session.change {$0.matchGrade?.amount=1}}.disabled(busy)
                    Button("Reset match",role:.destructive){session.change {$0.matchGrade=nil};message=nil}.disabled(busy)
                }
                if session.recipe.reference != nil {Button("Clear reference"){session.change {$0.reference=nil};message=nil}.font(.caption).disabled(busy)}
                if busy {ProgressView("Preparing comparison…")}
                if let message {Text(message).font(.caption).foregroundStyle(StudioStyle.blue)}
                if let error {Text(error).font(.caption).foregroundStyle(.orange)}
                Text("A reference is a saved visual target. Suggest a match compares overall brightness and color to give you a gentle starting point. Different subjects or lighting can need manual adjustments. Strength and Reset are reversible; clearing the reference keeps the correction.").font(.caption).foregroundStyle(StudioStyle.secondary)
                if session.recipe.hasCutout && session.recipe.background?.mode != .transparent {Text("The match adjusts the foreground. Your replacement background keeps its own settings.").font(.caption2).foregroundStyle(StudioStyle.secondary)}
                Text(session.project.isVideo ? "Video comparison uses the first kept frame. Play the clip in the editor to review the complete result. HDR is shown here as an SDR proof.":"HDR originals are compared as an SDR proof. Your export keeps its chosen HDR/SDR setting.").font(.caption2).foregroundStyle(StudioStyle.secondary)
            }.padding(16)}.frame(maxHeight:280).background(StudioStyle.panel)
        }.navigationTitle("Reference & Match").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}.disabled(busy)}.interactiveDismissDisabled(busy)}.tint(StudioStyle.blue)
        .task {await loadCurrent()}
        .task(id:session.recipe.reference?.id) {await loadReference()}
        .onChange(of:picker) {_,item in guard let item else {return};Task {do {guard let transfer=try await item.loadTransferable(type:PhotoTransfer.self) else {throw StudioError.unreadable};defer {try? FileManager.default.removeItem(at:transfer.url.deletingLastPathComponent())};await fromFile(transfer.url)} catch {self.error=error.localizedDescription};picker=nil}}
        .fileImporter(isPresented:$files,allowedContentTypes:[.image]) {result in if case .success(let url)=result {Task {let secured=url.startAccessingSecurityScopedResource();defer {if secured {url.stopAccessingSecurityScopedResource()}};await fromFile(url)}} else if case .failure(let e)=result {error=e.localizedDescription}}
    }
    private var referencePane:some View {
        VStack(spacing:5) {
            Text(session.recipe.reference?.name ?? "Choose a reference").font(.caption.weight(.semibold)).lineLimit(1)
            ZStack {Color.black.opacity(0.4);if let referenceCG {Image(decorative:referenceCG,scale:1).resizable().scaledToFit()} else {Image(systemName:"photo.badge.plus").font(.largeTitle).foregroundStyle(StudioStyle.secondary)}}.clipShape(RoundedRectangle(cornerRadius:12))
        }.frame(maxWidth:.infinity,maxHeight:.infinity).accessibilityIdentifier("referenceComparisonPane")
    }
    private var currentPane:some View {
        VStack(spacing:5) {
            Text(session.project.isVideo ? "Your edit · first kept frame":"Your edit").font(.caption.weight(.semibold))
            if let current {LivePreview(source:PhotoRendering.rawPreview(current,recipe:session.recipe),recipe:previewRecipe,signalSource:current.signalImage,original:false,active:phase == .active,stillFrame:currentFrame).clipShape(RoundedRectangle(cornerRadius:12))}
            else {ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity)}
        }.frame(maxWidth:.infinity,maxHeight:.infinity).accessibilityIdentifier("currentComparisonPane")
    }
    private func loadCurrent() async {
        if session.project.video == nil {current=session.source;return}
        guard let url=session.sourceURL,let video=session.project.video else {return}
        let time=firstTime
        do {let worker=Task.detached(priority:.utility) {try await VideoEngine.poster(url,descriptor:video,maxDimension:1536,time:time)};let loaded=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});if !Task.isCancelled {current=loaded}}
        catch {if !Task.isCancelled {self.error=error.localizedDescription}}
    }
    private func loadReference() async {
        guard let ref=session.recipe.reference,let source=session.sourceURL else {reference=nil;referenceCG=nil;return}
        reference=nil;referenceCG=nil
        let url=source.deletingLastPathComponent().appendingPathComponent(ref.filename)
        do {
            let worker=Task.detached(priority:.utility) {() throws -> (CIImage,CGImage) in let p=try ImageEngine.open(url,maxDimension:1536);guard let cg=ImageEngine.context().createCGImage(p.image,from:p.image.extent,format:.RGBA8,colorSpace:ImageEngine.output) else {throw StudioError.render};return (p.image,cg)}
            let result=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
            if !Task.isCancelled,session.recipe.reference?.id==ref.id {reference=result.0;referenceCG=result.1;error=nil}
        } catch {if !Task.isCancelled {reference=nil;referenceCG=nil;self.error="Reference unavailable. Choose the image again; your correction is still saved."}}
    }
    private func fromFile(_ url:URL) async {
        guard !busy else {return};busy=true;defer {busy=false};error=nil
        do {let ref=try await library.vault.importReference(url,project:session.project);session.change {$0.reference=ref};message=nil}
        catch {self.error=error.localizedDescription}
    }
    private func fromProject(_ p:Project) async {
        guard !busy else {return};busy=true;defer {busy=false};error=nil
        do {let ref=try await library.vault.referenceSnapshot(p,for:session.project);session.change {$0.reference=ref};message=nil}
        catch {self.error=error.localizedDescription}
    }
    private func suggest() async {
        guard !busy,let current,let reference else {return};busy=true;defer {busy=false};error=nil
        var r=session.recipe;r.matchGrade=nil
        let snapshot=session.recipe,refID=snapshot.reference?.id,l=light,c=color,s=richness,hdr=session.project.isVideo && r.video.hdr,frame=currentFrame
        do {
            let worker=Task.detached(priority:.utility) {let source=MaskMotion.$frame.withValue(frame) {ShotMatching.preview(current,recipe:r,videoHDR:hdr)};return ShotMatching.suggestion(source:try ShotMatching.statistics(source),reference:try ShotMatching.statistics(reference),light:l,color:c,richness:s)}
            let result=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
            guard !Task.isCancelled,session.recipe==snapshot,session.recipe.reference?.id==refID else {return}
            session.change {$0.matchGrade=result};message="Starting point applied. Adjust strength, then refine your grade in the editor."
        } catch {if !Task.isCancelled {self.error=error.localizedDescription}}
    }
}
