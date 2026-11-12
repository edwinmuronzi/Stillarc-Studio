import SwiftUI
import CoreImage

/// An on-demand full-resolution tile avoids retaining a second full-resolution display texture.
struct DetailInspectionSheet:View {
    @Bindable var session:EditSession
    @Environment(\.dismiss) private var dismiss
    @State private var x=0.5
    @State private var y=0.5
    @State private var prepared:PreparedPhoto?
    @State private var image:CGImage?
    @State private var busy=false
    @State private var error:String?
    private var key:String {"\(x):\(y):\(prepared != nil)"}
    var body:some View {
        NavigationStack {VStack(spacing:16) {
            if let image {Image(decorative:image,scale:1).resizable().interpolation(.none).scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity)} else {Spacer();ProgressView();Spacer()}
            VStack(alignment:.leading,spacing:12) {
                Text("Full-resolution detail · 1024-pixel tile").font(.headline)
                Text("Move through the finished image without loading a full-size screen texture. The original stays untouched. Close this view to resume editing.").font(.caption).foregroundStyle(StudioStyle.secondary)
                HStack {Text("Across").font(.caption);Slider(value:$x,in:0...1).accessibilityLabel("Inspect horizontal").sliderReset {x=0.5}}
                HStack {Text("Down").font(.caption);Slider(value:$y,in:0...1).accessibilityLabel("Inspect vertical").sliderReset {y=0.5}}
                if busy {ProgressView("Developing detail…")}
                if let error {Text(error).font(.caption).foregroundStyle(.orange)}
            }.padding(18).background(StudioStyle.panel)
        }.background(StudioStyle.ink).navigationTitle("Detail inspection").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}}.tint(StudioStyle.blue)
        .task {
            guard let url=session.sourceURL else {return};let recipe=session.recipe
            do {let worker=Task.detached(priority:.utility) {try ImageEngine.open(url,raw:recipe.rawDevelopment,hdr:recipe.photoHDR == true)};let p=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});if !Task.isCancelled {prepared=p}}
            catch {if !Task.isCancelled {self.error=error.localizedDescription}}
        }
        .task(id:key) {await render()}
    }
    private func render() async {
        guard let url=session.sourceURL,let photo=prepared else {return}
        do {
            try await Task.sleep(for:.milliseconds(160));try Task.checkCancellation();busy=true;error=nil
            let recipe=session.recipe,px=x,py=y
            let worker=Task.detached(priority:.utility) {() throws -> CGImage in
                let matte=try AutomaticMaskBitmap.prepare(recipe)
                let bg=try (recipe.background?.mode == .image ? recipe.background?.asset:nil).map {try BackgroundRendering.load($0,source:url,preview:false)}
                let graph=BackgroundRendering.$fullImage.withValue(bg) {AutomaticMaskBitmap.$prepared.withValue(matte) {HDRPipeline.grade(photo.image,recipe:recipe,hdr:recipe.photoHDR == true)}}
                let e=graph.extent,w=min(1024,e.width),h=min(1024,e.height)
                let tile=CGRect(x:e.minX+(e.width-w)*px,y:e.minY+(e.height-h)*(1-py),width:w,height:h).integral.intersection(e)
                let shown=recipe.photoHDR == true ? PhotoRendering.sdr(graph):graph
                try Task.checkCancellation()
                guard let result=ImageEngine.context().createCGImage(shown,from:tile,format:.RGBA8,colorSpace:ImageEngine.output) else {throw StudioError.render}
                return result
            }
            let loaded=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
            guard !Task.isCancelled else {return};image=loaded;busy=false
        } catch is CancellationError {} catch {if !Task.isCancelled {self.error=error.localizedDescription;busy=false}}
    }
}
