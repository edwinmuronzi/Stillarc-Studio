import CoreImage
import Foundation

struct RawDevelopment:Codable,Equatable,Sendable {
    var temperature:Double? = nil
    var tint:Double? = nil
    var exposure=0.0
    var boost:Double? = nil
    var lensProfile:Bool? = nil
    var recoverHighlights:Bool? = nil
    var colorNoise:Double? = nil
    var luminanceNoise:Double? = nil
    func apply(_ filter:CIRAWFilter,hdr:Bool) {
        if let temperature,temperature.isFinite {filter.neutralTemperature=Float(min(50000,max(2000,temperature)))}
        if let tint,tint.isFinite {filter.neutralTint=Float(min(150,max(-150,tint)))}
        filter.exposure=Float(exposure.isFinite ? min(4,max(-4,exposure)):0)
        if let boost {filter.boostAmount=Float(min(1,max(0,boost)))}
        if let lensProfile,filter.isLensCorrectionSupported {filter.isLensCorrectionEnabled=lensProfile}
        if #available(iOS 26,*),let recoverHighlights,filter.isHighlightRecoverySupported {filter.isHighlightRecoveryEnabled=recoverHighlights}
        if let colorNoise,filter.isColorNoiseReductionSupported {filter.colorNoiseReductionAmount=Float(min(1,max(0,colorNoise)))}
        if let luminanceNoise,filter.isLuminanceNoiseReductionSupported {filter.luminanceNoiseReductionAmount=Float(min(1,max(0,luminanceNoise)))}
        if hdr {filter.extendedDynamicRangeAmount=1}
    }
}
struct RawCapabilities:Sendable {
    var temperature:Double
    var tint:Double
    var boost:Double
    var lensEnabled:Bool
    var recoveryEnabled:Bool
    var colorNoiseAmount:Double
    var luminanceNoiseAmount:Double
    var lens:Bool
    var recovery:Bool
    var colorNoise:Bool
    var luminanceNoise:Bool
    init(_ f:CIRAWFilter) {
        temperature=Double(f.neutralTemperature);if !temperature.isFinite {temperature=6500};tint=Double(f.neutralTint);if !tint.isFinite {tint=0};boost=Double(f.boostAmount);lensEnabled=f.isLensCorrectionEnabled;colorNoiseAmount=Double(f.colorNoiseReductionAmount);luminanceNoiseAmount=Double(f.luminanceNoiseReductionAmount);lens=f.isLensCorrectionSupported;colorNoise=f.isColorNoiseReductionSupported;luminanceNoise=f.isLuminanceNoiseReductionSupported
        if #available(iOS 26,*) {recovery=f.isHighlightRecoverySupported;recoveryEnabled=f.isHighlightRecoveryEnabled} else {recovery=false;recoveryEnabled=false}
    }
}
struct PhotoOptics:Codable,Equatable,Sendable {var chromatic=0.0;var defringe=0.0}
enum PhotoRendering {
    private static let channels=CIColorKernel(source:"kernel vec4 channels(__sample r,__sample g,__sample b) {vec4 p=unpremultiply(g);return premultiply(vec4(unpremultiply(r).r,p.g,unpremultiply(b).b,p.a));}")
    private static let fringe=CIColorKernel(source:"kernel vec4 fringe(__sample src,__sample soft,float amount) {vec4 p=unpremultiply(src);vec3 b=unpremultiply(soft).rgb;float y=dot(p.rgb,vec3(0.2126,0.7152,0.0722));float edge=clamp(abs(y-dot(b,vec3(0.2126,0.7152,0.0722)))*12.0,0.0,1.0);float purple=step(p.g*1.15,min(p.r,p.b));float green=step(max(p.r,p.b)*1.2,p.g);return premultiply(vec4(mix(p.rgb,vec3(y),clamp(max(purple,green)*edge*amount,0.0,1.0)),p.a));}")
    private static let proof=CIColorKernel(source:"kernel vec4 proof(__sample src) {vec4 p=unpremultiply(src);float m=max(p.r,max(p.g,p.b));float mapped=m>0.75 ? 0.75+0.25*(1.0-exp(-(m-0.75)/0.25)):m;return premultiply(vec4(p.rgb*(m>0.000001 ? mapped/m:1.0),p.a));}")
    static func prepare() throws {guard channels != nil,fringe != nil,proof != nil else {throw StudioError.render}}
    static func sdr(_ image:CIImage) -> CIImage {proof?.apply(extent:image.extent,arguments:[image]) ?? image}
    static func optics(_ source:CIImage,_ settings:PhotoOptics?) -> CIImage {
        guard let settings else {return source};var image=source
        if settings.chromatic != 0 {
            let k=min(1,max(-1,settings.chromatic))*0.006
            image=channels?.apply(extent:source.extent,arguments:[LensRendering.apply(source,strength:k),source,LensRendering.apply(source,strength:-k)]) ?? source
        }
        if settings.defringe>0 {
            let soft=image.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:max(image.extent.width,image.extent.height)/1600]).cropped(to:image.extent)
            image=fringe?.apply(extent:image.extent,arguments:[image,soft,min(1,settings.defringe)]) ?? image
        }
        return image
    }
    static func rawPreview(_ source:PreparedPhoto,recipe:Recipe) -> CIImage {
        guard source.isRAW,let cap=source.rawCapabilities else {return source.image}
        let old=source.rawApplied ?? RawDevelopment(),target=recipe.rawDevelopment ?? RawDevelopment()
        var image=source.image
        if old.exposure != target.exposure {image=image.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:target.exposure-old.exposure])}
        let a=CIVector(x:old.temperature ?? cap.temperature,y:old.tint ?? cap.tint),b=CIVector(x:target.temperature ?? cap.temperature,y:target.tint ?? cap.tint)
        if a != b {image=image.applyingFilter("CITemperatureAndTint",parameters:["inputNeutral":a,"inputTargetNeutral":b])}
        return image
    }
}
