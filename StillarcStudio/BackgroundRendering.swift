import CoreImage
import Foundation

enum PhotoBackgroundMode:String,Codable,CaseIterable,Identifiable {case transparent="Transparent",solid="Solid",image="Image",blur="Blur original";var id:String {rawValue}}
struct BackgroundAsset:Codable,Equatable,Sendable {let id:UUID;let width:Int;let height:Int;var filename:String {"background-"+id.uuidString+".asset"}}
struct PhotoBackground:Codable,Equatable,Sendable {
    var mode=PhotoBackgroundMode.transparent
    var red=0.12;var green=0.14;var blue=0.18
    var asset:BackgroundAsset? = nil
    var fill=true
    var scale=1.0
    var x=0.5;var y=0.5
    var blur=0.0
    var exposure=0.0
    var saturation=0.0
}
extension Recipe {var hasTransparentCutout:Bool {hasCutout && (background?.mode ?? .transparent) == .transparent}}
enum BackgroundRendering {
    private final class Cache:@unchecked Sendable {
        let lock=NSLock();var images:[UUID:CIImage]=[:];var order=[UUID]();var pinned:UUID?
        func store(_ image:CIImage,_ id:UUID) {lock.lock();defer {lock.unlock()};images[id]=image;order.removeAll {$0==id};order.append(id);while order.count>3 {let index=order.firstIndex(where:{$0 != pinned}) ?? 0;images.removeValue(forKey:order.remove(at:index))}}
        func get(_ id:UUID) -> CIImage? {lock.lock();defer {lock.unlock()};return images[id]}
    }
    private static let cache=Cache()
    @TaskLocal static var fullImage:CIImage?
    static func pin(_ id:UUID?) {cache.lock.lock();cache.pinned=id;cache.lock.unlock()}
    static func load(_ asset:BackgroundAsset,source:URL,preview:Bool) throws -> CIImage {
        if preview,let image=cache.get(asset.id) {return image}
        let url=source.deletingLastPathComponent().appendingPathComponent(asset.filename)
        let photo=try ImageEngine.open(url,maxDimension:preview ? 1600:nil)
        if preview {cache.store(photo.image,asset.id)}
        return photo.image
    }
    static func composite(_ foreground:CIImage,original:CIImage,recipe:Recipe) -> CIImage {
        guard recipe.hasCutout,let s=recipe.background,s.mode != .transparent else {return foreground}
        let e=foreground.extent,color=CIColor(red:min(1,max(0,s.red)),green:min(1,max(0,s.green)),blue:min(1,max(0,s.blue)),alpha:1,colorSpace:ImageEngine.output)!
        var bg=CIImage(color:color).cropped(to:e)
        if s.mode == .image,let asset=s.asset,let picture=fullImage ?? cache.get(asset.id) {
            let factor=(s.fill ? max(e.width/picture.extent.width,e.height/picture.extent.height):min(e.width/picture.extent.width,e.height/picture.extent.height))*min(4,max(0.25,s.scale))
            let w=picture.extent.width*factor,h=picture.extent.height*factor
            let placed=picture.transformed(by:.init(translationX:-picture.extent.minX,y:-picture.extent.minY)).transformed(by:.init(scaleX:factor,y:factor)).transformed(by:.init(translationX:e.minX+(e.width-w)*min(1,max(0,s.x)),y:e.minY+(e.height-h)*(1-min(1,max(0,s.y)))))
            bg=placed.composited(over:bg).cropped(to:e)
        } else if s.mode == .blur {bg=original.composited(over:bg).cropped(to:e)}
        if s.blur>0 {
            bg=bg.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:min(1,s.blur)*max(e.width,e.height)/1600*20]).cropped(to:e)
        }
        if s.exposure != 0 {bg=bg.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:min(3,max(-3,s.exposure))])}
        if s.saturation != 0 {bg=bg.applyingFilter("CIColorControls",parameters:[kCIInputSaturationKey:1+min(1,max(-1,s.saturation))])}
        return foreground.composited(over:bg).cropped(to:e)
    }
}
extension ProjectVault {
    func importBackground(_ url:URL,project:Project) throws -> BackgroundAsset {
        let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size>0,size<=150_000_000 else {throw StudioError.unreadable}
        let prepared=try ImageEngine.open(url,maxDimension:1600)
        let asset=BackgroundAsset(id:UUID(),width:prepared.width,height:prepared.height)
        let target=source(project).deletingLastPathComponent().appendingPathComponent(asset.filename)
        try FileManager.default.copyItem(at:url,to:target)
        _ = try BackgroundRendering.load(asset,source:source(project),preview:true)
        return asset
    }
}
