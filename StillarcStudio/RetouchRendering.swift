import CoreImage
import Foundation

enum RetouchKind:String,Codable,CaseIterable,Identifiable {case heal="Heal",clone="Clone";var id:String {rawValue}}
struct RetouchSpot:Codable,Equatable,Identifiable,Sendable {
    var id=UUID();var x:Double;var y:Double;var sourceX:Double;var sourceY:Double;var radius:Double;var kind:RetouchKind
}
enum RetouchRendering {
    private static let match=CIColorKernel(source:"kernel vec4 studioHeal(__sample src,__sample meanA,__sample meanB) {if(meanA.a<0.001 || meanB.a<0.001) return src;vec4 p=unpremultiply(src);return premultiply(vec4(max(vec3(0.0),p.rgb-unpremultiply(meanA).rgb+unpremultiply(meanB).rgb),p.a));}")
    static func prepare() throws {guard match != nil else {throw StudioError.render}}
    static func apply(_ original:CIImage,spots:[RetouchSpot]?) -> CIImage {
        guard let spots,!spots.isEmpty else {return original}
        var image=original;let e=original.extent
        for s in spots.prefix(32) {
            let x=e.minX+e.width*min(1,max(0,s.x)),y=e.minY+e.height*(1-min(1,max(0,s.y)))
            let sx=e.minX+e.width*min(1,max(0,s.sourceX)),sy=e.minY+e.height*(1-min(1,max(0,s.sourceY))),radius=min(e.width,e.height)*min(0.15,max(0.005,s.radius))
            var patch=original.clampedToExtent().transformed(by:.init(translationX:x-sx,y:y-sy)).cropped(to:e)
            if s.kind == .heal {
                let from=original.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:CGRect(x:sx-radius,y:sy-radius,width:radius*2,height:radius*2).intersection(e))]).clampedToExtent()
                let ring=CIFilter(name:"CIRadialGradient",parameters:["inputCenter":CIVector(x:x,y:y),"inputRadius0":radius*0.9,"inputRadius1":radius*1.4,"inputColor0":CIColor.black,"inputColor1":CIColor.white])!.outputImage!
                let surrounding=original.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:CIImage(color:.clear),kCIInputMaskImageKey:ring])
                let to=surrounding.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:CGRect(x:x-radius*1.6,y:y-radius*1.6,width:radius*3.2,height:radius*3.2).intersection(e))]).clampedToExtent()
                patch=match?.apply(extent:e,arguments:[patch,from,to]) ?? patch
            }
            let weight=CIFilter(name:"CIRadialGradient",parameters:["inputCenter":CIVector(x:x,y:y),"inputRadius0":radius*0.6,"inputRadius1":radius,"inputColor0":CIColor.white,"inputColor1":CIColor.black])!.outputImage!
            image=patch.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:image,kCIInputMaskImageKey:weight]).cropped(to:e)
        }
        return image
    }
}
