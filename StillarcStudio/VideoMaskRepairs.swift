import CoreImage
import Foundation

struct VideoMaskRepairPoint:Identifiable,Codable,Equatable,Sendable {
    var id=UUID()
    var time:Double
    var add=BrushDrawing()
    var subtract=BrushDrawing()
}
struct VideoMaskRepairs:Codable,Equatable,Sendable {
    var points=[VideoMaskRepairPoint]()
    var markers=[Double]()
    var dismissedHints=[Double]()
    var transition=MaskCorrectionBlend.smooth
    var isValid:Bool {
        points.count<=16 && markers.count<=64 && dismissedHints.count<=128 && dismissedHints.allSatisfy {$0.isFinite && $0>=0 && $0<=604800} && Set(points.map(\.id)).count==points.count &&
        points.allSatisfy {$0.time.isFinite && $0.time>=0 && $0.time<=604800 && $0.add.strokes.count<=16 && $0.subtract.strokes.count<=16} &&
        points.reduce(0){$0+$1.add.strokes.reduce(0){$0+$1.points.count}+$1.subtract.strokes.reduce(0){$0+$1.points.count}}<=32768 &&
        zip(points,points.dropFirst()).allSatisfy {$0.time<$1.time} && markers.allSatisfy {$0.isFinite && $0>=0 && $0<=604800}
    }
    private enum CodingKeys:String,CodingKey {case points,markers,dismissedHints,transition}
    init() {}
    init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        points=try c.decodeIfPresent([VideoMaskRepairPoint].self,forKey:.points) ?? []
        markers=try c.decodeIfPresent([Double].self,forKey:.markers) ?? []
        dismissedHints=try c.decodeIfPresent([Double].self,forKey:.dismissedHints) ?? []
        transition=try c.decodeIfPresent(MaskCorrectionBlend.self,forKey:.transition) ?? .smooth
        guard isValid else {throw AutomaticSelectionEngine.error("This saved video repair exceeds supported limits or has invalid timing.")}
    }
    func neighbors(at time:Double,start:Double)->(VideoMaskRepairPoint?,VideoMaskRepairPoint?,Double) {
        guard time.isFinite,let first=points.first,let last=points.last else {return (nil,nil,0)}
        if time<first.time {return (nil,first,transition.fraction((time-start)/max(0.000001,first.time-start)))}
        if time>=last.time {return (last,nil,0)}
        var low=0,high=points.count-1
        while high-low>1 {let m=(low+high)/2;if points[m].time<=time {low=m} else {high=m}}
        return (points[low],points[high],transition.fraction((time-points[low].time)/(points[high].time-points[low].time)))
    }
    mutating func point(at time:Double,tolerance:Double)->Int? {
        guard time.isFinite,time>=0,time<=604800 else {return nil}
        if let i=points.firstIndex(where:{abs($0.time-time)<=tolerance}) {return i}
        guard points.count<16 else {return nil}
        points.append(.init(time:time));points.sort {$0.time<$1.time};return points.firstIndex {$0.time==time}
    }
}
enum VideoMaskRepairRendering {
    private final class Box:NSObject {let image:CGImage;init(_ image:CGImage){self.image=image}}
    private final class Cache:@unchecked Sendable {
        let images=NSCache<NSString,Box>()
        init(){images.countLimit=32;images.totalCostLimit=48_000_000}
    }
    private static let cache=Cache()
    static func drawing(_ drawing:BrushDrawing,extent:CGRect,preview:Bool)->CIImage {
        guard !drawing.strokes.isEmpty else {return CIImage(color:.black).cropped(to:extent)}
        if preview {return BrushMaskRasterizer.image(drawing,extent:extent,preview:true)}
        let key="\(drawing.id)-\(drawing.revision)-\(Int(extent.width))x\(Int(extent.height))" as NSString
        if let box=cache.images.object(forKey:key) {return CIImage(cgImage:box.image,options:[.colorSpace:NSNull()])}
        let image=BrushMaskRasterizer.$preparedExport.withValue(nil) {BrushMaskRasterizer.image(drawing,extent:extent,preview:false)}
        guard let cg=ImageEngine.context().createCGImage(image,from:extent,format:.L8,colorSpace:CGColorSpace(name:CGColorSpace.linearGray)) else {return image}
        cache.images.setObject(Box(cg),forKey:key,cost:cg.bytesPerRow*cg.height)
        return CIImage(cgImage:cg,options:[.colorSpace:NSNull()])
    }
    static func apply(_ mask:CIImage,repairs:VideoMaskRepairs?,matte:TemporalMatte,framing:String,time:Double,preview:Bool)->CIImage {
        guard let repairs,!repairs.points.isEmpty,repairs.points.count<=16,let recipe=TemporalMatteProjection.recipe(framing) else {return mask}
        let scale=min(1,1536/Double(max(matte.sourceWidth,matte.sourceHeight)))
        let e=CGRect(x:0,y:0,width:max(1,floor(Double(matte.sourceWidth)*scale)),height:max(1,floor(Double(matte.sourceHeight)*scale)))
        let (a,b,f)=repairs.neighbors(at:time,start:matte.start)
        func field(_ point:VideoMaskRepairPoint?,add:Bool)->CIImage {
            guard let point else {return CIImage(color:.black).cropped(to:e)}
            return drawing(add ? point.add:point.subtract,extent:e,preview:preview)
        }
        func blend(add:Bool)->CIImage {
            let first=field(a,add:add),second=field(b,add:add)
            let mixed=b == nil ? first:second.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:first,kCIInputTimeKey:1-f])
            let framed=PhotoFraming.apply(mixed,recipe:recipe),r=framed.extent,target=mask.extent
            return framed.transformed(by:.init(translationX:-r.minX,y:-r.minY)).transformed(by:.init(scaleX:target.width/r.width,y:target.height/r.height)).transformed(by:.init(translationX:target.minX,y:target.minY)).cropped(to:target)
        }
        return mask.applyingFilter("CIMaximumCompositing",parameters:[kCIInputBackgroundImageKey:blend(add:true)])
            .applyingFilter("CIMultiplyCompositing",parameters:[kCIInputBackgroundImageKey:blend(add:false).applyingFilter("CIColorInvert")]).cropped(to:mask.extent)
    }
}
