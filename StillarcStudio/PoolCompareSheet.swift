import SwiftUI
import CoreImage

actor PoolCompareCache {
    static let shared=PoolCompareCache()
    private var images=[String:CGImage](),order=[String]()
    func image(_ project:Project,vault:ProjectVault) async throws ->CGImage {
        let key="\(project.id)-\(project.modified.timeIntervalSince1970)"
        if let cg=images[key] {return cg}
        try Task.checkCancellation()
        guard ProcessInfo.processInfo.thermalState.rawValue<ProcessInfo.ThermalState.serious.rawValue else {throw AutomaticSelectionEngine.error("Let Studio cool before preparing this comparison.")}
        let url=await vault.source(project),r=project.recipe,photo:PreparedPhoto
        try Task.checkCancellation()
        if let video=project.video {photo=try await VideoEngine.poster(url,descriptor:video,maxDimension:640,time:r.video.start)}
        else {photo=try ImageEngine.open(url,maxDimension:640,raw:r.rawDevelopment,hdr:r.photoHDR == true)}
        let prepared=try AutomaticMaskBitmap.prepare(r),background=try (r.background?.mode == .image ? r.background?.asset:nil).map {try BackgroundRendering.load($0,source:url,preview:true)}
        let image=BackgroundRendering.$fullImage.withValue(background){AutomaticMaskBitmap.$prepared.withValue(prepared){MaskMotion.$frame.withValue(.init(time:r.video.start,framing:MaskMotion.signature(r))){ShotMatching.preview(photo,recipe:r,videoHDR:project.video != nil && r.video.hdr)}}}
        let scale=min(1,640/max(image.extent.width,image.extent.height)),small=image.transformed(by:.init(scaleX:scale,y:scale))
        guard let cg=ImageEngine.context().createCGImage(small,from:small.extent,format:.RGBA8,colorSpace:ImageEngine.output) else {throw StudioError.render}
        try Task.checkCancellation();images[key]=cg;order.removeAll {$0==key};order.append(key)
        while order.count>6 {images.removeValue(forKey:order.removeFirst())}
        return cg
    }
}
struct PoolCompareSheet:View {
    let projects:[Project]
    let reference:Project
    let vault:ProjectVault
    @Environment(\.dismiss) private var dismiss
    @State private var index=0
    @State private var referenceImage:CGImage?
    @State private var targetImage:CGImage?
    @State private var message:String?
    @State private var zoom=1.0
    private var targets:[Project] {projects.filter {$0.id != reference.id}}
    var body:some View {
        NavigationStack {VStack(spacing:12) {
            GeometryReader {g in
                let wide=g.size.width>g.size.height*1.2
                let layout=wide ? AnyLayout(HStackLayout(spacing:12)):AnyLayout(VStackLayout(spacing:12))
                layout {pane(reference,referenceImage);if targets.indices.contains(index) {pane(targets[index],targetImage)}}
            }.gesture(DragGesture(minimumDistance:50).onEnded {v in if abs(v.translation.width)>abs(v.translation.height)*2 {index=min(max(0,index+(v.translation.width<0 ? 1:-1)),max(0,targets.count-1))}})
            HStack {Button("Previous"){index=max(0,index-1)}.disabled(index==0);Spacer();Text("\(targets.isEmpty ? 0:index+1) / \(targets.count)").monospacedDigit().accessibilityIdentifier("poolComparePosition");Spacer();Button("Next"){index=min(targets.count-1,index+1)}.disabled(index+1>=targets.count)}.buttonStyle(.bordered).font(.caption)
            HStack {Text("Compare zoom");Slider(value:$zoom,in:1...3).accessibilityLabel("Pool comparison zoom").sliderReset {zoom=1};Button("Fit"){zoom=1}}.font(.caption)
            if let message {Text(message).font(.caption).foregroundStyle(.orange)}
            Text("Graded SDR proofs. Videos show the first kept frame; HDR is tone-mapped for this comparison. Swipe between pool items. This view changes no edits.").font(.caption).foregroundStyle(StudioStyle.secondary)
        }.padding(16).background(StudioStyle.ink).navigationTitle("Compare pool shots").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}}.tint(StudioStyle.blue)
        .task {do {referenceImage=try await PoolCompareCache.shared.image(reference,vault:vault)} catch {message=error.localizedDescription}}
        .task(id:index) {
            targetImage=nil;message=nil;guard targets.indices.contains(index) else {return};let p=targets[index]
            do {let cg=try await PoolCompareCache.shared.image(p,vault:vault);if !Task.isCancelled {targetImage=cg}} catch {if !Task.isCancelled {message=error.localizedDescription}}
        }
    }
    private func pane(_ project:Project,_ cg:CGImage?)->some View {
        VStack(spacing:6){Text(project.name).font(.caption.weight(.semibold)).lineLimit(1);ZStack {Color.black;if let cg {Image(decorative:cg,scale:1).resizable().scaledToFit().scaleEffect(zoom)} else {ProgressView()}}.clipped().clipShape(RoundedRectangle(cornerRadius:16))}.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}
