import Foundation
import CoreImage

struct PhotoReference:Codable,Equatable,Sendable {
    var id=UUID()
    var name:String
    var filename:String {"reference-\(id.uuidString).png"}
}
struct MatchGrade:Codable,Equatable,Sendable {
    var exposure=0.0
    var red=1.0
    var green=1.0
    var blue=1.0
    var saturation=1.0
    var amount=1.0
    var isNeutral:Bool {amount==0 || (abs(exposure)<0.000001 && abs(red-1)<0.000001 && abs(green-1)<0.000001 && abs(blue-1)<0.000001 && abs(saturation-1)<0.000001)}
    func validated() -> Self {
        var r=self
        func limit(_ v:Double,_ low:Double,_ high:Double,_ fallback:Double) -> Double {v.isFinite ? min(high,max(low,v)):fallback}
        r.exposure=limit(exposure,-1.5,1.5,0);r.red=limit(red,0.7,1.4,1);r.green=limit(green,0.7,1.4,1);r.blue=limit(blue,0.7,1.4,1);r.saturation=limit(saturation,0.75,1.25,1);r.amount=limit(amount,0,1,1);return r
    }
}
enum ShotMatching {
    private static let context=ImageEngine.context()
    struct Statistics:Sendable {var median:Double;var red:Double;var green:Double;var blue:Double;var saturation:Double}
    static func apply(_ source:CIImage,_ raw:MatchGrade?) -> CIImage {
        guard let raw else {return source};let g=raw.validated();guard !g.isNeutral else {return source}
        var image=source
        if g.exposure != 0 {image=image.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:g.exposure*g.amount])}
        if g.red != 1 || g.green != 1 || g.blue != 1 {
            image=image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:1+(g.red-1)*g.amount,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:1+(g.green-1)*g.amount,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:1+(g.blue-1)*g.amount,w:0)])
        }
        if g.saturation != 1 {image=image.applyingFilter("CIColorControls",parameters:[kCIInputSaturationKey:1+(g.saturation-1)*g.amount])}
        return image
    }
    /// Bounded, request-only image statistics in the renderer's linear working space.
    static func statistics(_ image:CIImage) throws -> Statistics {
        try Task.checkCancellation()
        let w=96,h=96,e=image.extent
        guard e.width>0,e.height>0,e.width.isFinite,e.height.isFinite else {throw StudioError.unreadable}
        let tiny=image.transformed(by:.init(translationX:-e.minX,y:-e.minY)).transformed(by:.init(scaleX:Double(w)/e.width,y:Double(h)/e.height))
        var p=[Float](repeating:0,count:w*h*4)
        context.render(tiny,toBitmap:&p,rowBytes:w*16,bounds:CGRect(x:0,y:0,width:w,height:h),format:.RGBAf,colorSpace:ImageEngine.working)
        var values=[(Double,Double,Double,Double,Double)]();values.reserveCapacity(w*h)
        for i in 0..<w*h {
            let j=i*4;guard p[j].isFinite,p[j+1].isFinite,p[j+2].isFinite,p[j+3].isFinite,p[j+3]>0.98 else {continue}
            let r=min(1,max(0,Double(p[j]))),g=min(1,max(0,Double(p[j+1]))),b=min(1,max(0,Double(p[j+2]))),y=0.2126*r+0.7152*g+0.0722*b
            guard y>0.005,y<0.98 else {continue}
            let peak=max(r,max(g,b));values.append((y,r,g,b,peak>0.01 ? (peak-min(r,min(g,b)))/peak:0))
        }
        guard values.count>=64 else {throw NSError(domain:"ShotMatch",code:1,userInfo:[NSLocalizedDescriptionKey:"There is not enough visible midtone detail to suggest a match. Try a brighter reference or adjust the image manually."])}
        values.sort {$0.0<$1.0};let cropped=values.dropFirst(values.count/20).dropLast(values.count/20),n=Double(cropped.count)
        return Statistics(median:values[values.count/2].0,red:cropped.reduce(0){$0+$1.1}/n,green:cropped.reduce(0){$0+$1.2}/n,blue:cropped.reduce(0){$0+$1.3}/n,saturation:cropped.reduce(0){$0+$1.4}/n)
    }
    static func suggestion(source:Statistics,reference:Statistics,light:Bool,color:Bool,richness:Bool) -> MatchGrade {
        var g=MatchGrade()
        if light {g.exposure=log2(max(0.005,reference.median)/max(0.005,source.median))}
        if color {
            let a=0.2126*source.red+0.7152*source.green+0.0722*source.blue,b=0.2126*reference.red+0.7152*reference.green+0.0722*reference.blue
            g.red=(reference.red/max(b,0.005))/(max(0.005,source.red)/max(a,0.005));g.green=(reference.green/max(b,0.005))/(max(0.005,source.green)/max(a,0.005));g.blue=(reference.blue/max(b,0.005))/(max(0.005,source.blue)/max(a,0.005))
            g=g.validated()
            let corrected=0.2126*source.red*g.red+0.7152*source.green*g.green+0.0722*source.blue*g.blue,scale=a/max(0.005,corrected)
            g.red *= scale;g.green *= scale;g.blue *= scale
        }
        if richness {g.saturation=(reference.saturation+0.03)/(source.saturation+0.03)}
        return g.validated()
    }
    static func preview(_ photo:PreparedPhoto,recipe:Recipe,videoHDR:Bool=false) -> CIImage {
        let input=photo.isRAW ? PhotoRendering.rawPreview(photo,recipe:recipe):photo.source(for:recipe)
        let hdr=videoHDR || recipe.photoHDR == true
        let graded=HDRPipeline.grade(input,recipe:recipe,hdr:hdr,preview:true)
        return hdr ? PhotoRendering.sdr(graded):graded
    }
}
extension ProjectVault {
    func importReference(_ url:URL,project:Project) throws -> PhotoReference {
        let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size>0,size<=150_000_000 else {throw StudioError.unreadable}
        let prepared=try ImageEngine.open(url,maxDimension:1536)
        return try storeReference(prepared.image,name:url.deletingPathExtension().lastPathComponent,project:project)
    }
    func referenceSnapshot(_ reference:Project,for destination:Project) async throws -> PhotoReference {
        let url=source(reference),p:PreparedPhoto
        if let video=reference.video {p=try await VideoEngine.poster(url,descriptor:video,maxDimension:1536,time:reference.recipe.video.start)}
        else {p=try ImageEngine.open(url,maxDimension:1536,raw:reference.recipe.rawDevelopment,hdr:reference.recipe.photoHDR == true)}
        let recipe=try await MaskFramingRepair.repair(recipe:reference.recipe,url:url,video:reference.video,prepared:p)
        let masks=try AutomaticMaskBitmap.prepare(recipe)
        let bg=try (recipe.background?.mode == .image ? recipe.background?.asset:nil).map {try BackgroundRendering.load($0,source:url,preview:true)}
        let image=BackgroundRendering.$fullImage.withValue(bg) {AutomaticMaskBitmap.$prepared.withValue(masks) {MaskMotion.$frame.withValue(.init(time:recipe.video.start,framing:MaskMotion.signature(recipe))) {ShotMatching.preview(p,recipe:recipe,videoHDR:reference.video != nil && recipe.video.hdr)}}}
        return try storeReference(image,name:reference.name+" · snapshot",project:destination)
    }
    private func storeReference(_ image:CIImage,name:String,project:Project) throws -> PhotoReference {
        try Task.checkCancellation()
        let ref=PhotoReference(name:String(name.prefix(100))),target=source(project).deletingLastPathComponent().appendingPathComponent(ref.filename)
        try ImageEngine.context().writePNGRepresentation(of:image,to:target,format:.RGBA8,colorSpace:ImageEngine.output)
        return ref
    }
}
