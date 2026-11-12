import CoreImage
import ImageIO
import Foundation

struct AutomaticMaskAnchor:Codable,Equatable,Sendable {
    let id:UUID;let png:Data;let width:Int;let height:Int;let framing:String
}

struct AutomaticMask:Codable,Equatable,Sendable {
    let id:UUID
    let png:Data
    let width:Int
    let height:Int
    let framing:String
    let videoStart:Double?
    var anchor:AutomaticMaskAnchor? = nil
    var bounded:Bool { !png.isEmpty && png.count<=4_194_304 && width>0 && height>0 && width<=1536 && height<=1536 }
    func matches(_ recipe:Recipe) -> Bool {
        framing == MaskMotion.signature(recipe) && (videoStart == nil || abs((videoStart ?? 0)-recipe.video.start)<0.002)
    }
}
struct AutomaticRefinement:Codable,Equatable,Sendable {
    var threshold = 0.5
    var transition = 1.0
    var expand = 0.0
    var softness = 0.0
    func validated() -> Self {
        var r = self
        func clamp(_ n:Double,_ range:ClosedRange<Double>,_ fallback:Double) -> Double { n.isFinite ? min(range.upperBound,max(range.lowerBound,n)) : fallback }
        r.threshold = clamp(threshold,0.05...0.95,0.5);r.transition = clamp(transition,0.02...1,1)
        r.expand = clamp(expand,-0.01...0.01,0);r.softness = clamp(softness,0...0.01,0)
        return r
    }
}
enum AutomaticMaskBitmap {
    private final class Cache:@unchecked Sendable {
        let lock = NSLock(),queue = DispatchQueue(label:"studio.automatic-matte",qos:.userInitiated)
        var images:[UUID:CGImage] = [:],pending = Set<UUID>(),failed = Set<UUID>(),order = [UUID]()
        func store(_ image:CGImage,id:UUID) {
            lock.lock();defer { lock.unlock() };images[id] = image;order.removeAll { $0 == id };order.append(id)
            while order.count>8 { images.removeValue(forKey:order.removeFirst()) }
        }
        func get(_ mask:AutomaticMask,preview:Bool) -> CGImage? {
            lock.lock();let found = images[mask.id],bad = failed.contains(mask.id);lock.unlock();if bad { return nil };if let found { return found }
            if !preview { if let image = AutomaticMaskBitmap.decode(mask) { store(image,id:mask.id);return image };return nil }
            lock.lock();let inserted = pending.insert(mask.id).inserted;lock.unlock()
            if inserted { queue.async {
                if let image = AutomaticMaskBitmap.decode(mask) { self.store(image,id:mask.id) } else { self.lock.lock();if self.failed.count>=16 { self.failed.removeAll() };self.failed.insert(mask.id);self.lock.unlock() }
                self.lock.lock();self.pending.remove(mask.id);self.lock.unlock()
                DispatchQueue.main.async { NotificationCenter.default.post(name:.studioBrushReady,object:mask.id) }
            } }
            return nil
        }
    }
    private static let cache = Cache()
    @TaskLocal static var prepared:[UUID:CGImage]?
    static func decode(_ mask:AutomaticMask) -> CGImage? {
        guard mask.bounded,let source = CGImageSourceCreateWithData(mask.png as CFData,nil),let props = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],props[kCGImagePropertyPixelWidth] as? Int == mask.width,props[kCGImagePropertyPixelHeight] as? Int == mask.height else { return nil }
        return CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCacheImmediately:true] as CFDictionary)
    }
    static func make(_ image:CIImage,recipe:Recipe,videoStart:Double?) throws -> AutomaticMask {
        let gray = CGColorSpace(name:CGColorSpace.linearGray)!,context = ImageEngine.context()
        let scale = min(1,1024/max(image.extent.width,image.extent.height))
        var bounded = image.transformed(by:.init(scaleX:scale,y:scale));bounded = bounded.transformed(by:.init(translationX:-bounded.extent.minX,y:-bounded.extent.minY))
        bounded = bounded.cropped(to:CGRect(x:0,y:0,width:max(1,floor(bounded.extent.width)),height:max(1,floor(bounded.extent.height))))
        guard let png = context.pngRepresentation(of:bounded,format:.L16,colorSpace:gray,options:[:]) else { throw StudioError.render }
        let mask = AutomaticMask(id:UUID(),png:png,width:Int(bounded.extent.width),height:Int(bounded.extent.height),framing:MaskMotion.signature(recipe),videoStart:videoStart)
        guard let decoded = decode(mask) else { throw StudioError.render };cache.store(decoded,id:mask.id);return mask
    }
    static func warm(_ layers:[LocalMask]) { for layer in layers { if let mask = layer.automatic { _ = cache.get(mask,preview:false) } } }
    static func prepare(_ recipe:Recipe) throws -> [UUID:CGImage] {
        var images:[UUID:CGImage] = [:]
        for index in MaskEngine.requiredIndices(recipe.masks) where recipe.masks[index].kind.isAutomatic {
            guard let mask = recipe.masks[index].automatic,mask.matches(recipe),let cg = cache.get(mask,preview:false) else { throw NSError(domain:"AutomaticMask",code:1,userInfo:[NSLocalizedDescriptionKey:"Recreate the automatic mask after changing the crop or clip start, or delete it before exporting."]) }
            images[mask.id] = cg
        }
        return images
    }
    static func image(_ mask:AutomaticMask?,extent:CGRect,preview:Bool) -> CIImage? {
        guard let mask,let cg = prepared?[mask.id] ?? cache.get(mask,preview:preview) else { return nil }
        return CIImage(cgImage:cg,options:[.colorSpace:NSNull()]).transformed(by:.init(scaleX:extent.width/Double(cg.width),y:extent.height/Double(cg.height))).transformed(by:.init(translationX:extent.minX,y:extent.minY)).cropped(to:extent)
    }
}
