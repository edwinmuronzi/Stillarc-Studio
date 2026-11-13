import Foundation
import CoreImage
import Metal

enum CameraLogProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard, appleLog, appleLog2, sonySLog3Cine, panasonicVLog, canonLog3, nikonNLog, fujiFLog2, djiDLog, encodedSRGB, encodedP3, linearSRGB
    var id:String { rawValue }
    var title:String { switch self { case .encodedSRGB:"Encoded sRGB · manual override";case .encodedP3:"Display P3 · manual override";case .linearSRGB:"Linear sRGB · manual override";case .standard:"Standard / already converted"; case .appleLog:"Apple Log · Rec.2020"; case .appleLog2:"Apple Log 2 · Apple Wide Gamut"; case .sonySLog3Cine:"Sony S-Log3 · S-Gamut3.Cine"; case .panasonicVLog:"Panasonic V-Log · V-Gamut"; case .canonLog3:"Canon Log 3 · Rec.2020"; case .nikonNLog:"Nikon N-Log · Rec.2020"; case .fujiFLog2:"Fujifilm F-Log2 · F-Gamut"; case .djiDLog:"DJI D-Log · D-Gamut (X9 native EI)" } }
    var shortTitle:String { switch self { case .encodedSRGB:"sRGB OVERRIDE";case .encodedP3:"P3 OVERRIDE";case .linearSRGB:"LINEAR sRGB";case .standard:"STANDARD"; case .appleLog:"APPLE LOG"; case .appleLog2:"APPLE LOG 2"; case .sonySLog3Cine:"SONY S-LOG3"; case .panasonicVLog:"PANASONIC V-LOG"; case .canonLog3:"CANON LOG 3"; case .nikonNLog:"NIKON N-LOG"; case .fujiFLog2:"FUJI F-LOG2"; case .djiDLog:"DJI D-LOG" } }
    var technicalColorSpace:CGColorSpace? {
        switch self {case .encodedSRGB:CGColorSpace(name:CGColorSpace.sRGB);case .encodedP3:CGColorSpace(name:CGColorSpace.displayP3);case .linearSRGB:CGColorSpace(name:CGColorSpace.extendedLinearSRGB);default:nil}
    }
    var kernelIndex:Double { switch self {case .sonySLog3Cine:1;case .panasonicVLog:2;case .canonLog3:3;case .nikonNLog:4;case .fujiFLog2:5;case .djiDLog:6;default:0} }
    var matrix:[[Double]] {
        switch self {
        case .standard,.encodedSRGB,.encodedP3,.linearSRGB: [[1,0,0],[0,1,0],[0,0,1]]
        case .appleLog, .canonLog3, .nikonNLog, .fujiFLog2: [[1.660491002108,-0.587641138789,-0.072849863320],[-0.124550474522,1.132899897126,-0.008349422604],[-0.018150763355,-0.100578898008,1.118729661363]]
        case .appleLog2: [[1.707280377174,-0.519019919932,-0.188260457242],[-0.125010746108,1.314662365482,-0.189651619374],[-0.043624333388,-0.191214371733,1.234838705120]]
        case .sonySLog3Cine: [[1.626947409729,-0.540138538870,-0.086808870859],[-0.178515527115,1.417940927464,-0.239425400349],[-0.044436115009,-0.195919966172,1.240356081181]]
        case .djiDLog: [[1.6746,-0.5797,-0.0949],[-0.0981,1.3340,-0.2359],[-0.0410,-0.2430,1.2840]]
        case .panasonicVLog: [[1.806575883725,-0.695697274084,-0.110878609641],[-0.170090343102,1.305955216095,-0.135864872993],[-0.025205784017,-0.154468329361,1.179674113377]]
        }
    }
}
struct InputConversion: Codable, Equatable, Sendable {
    var profile = CameraLogProfile.standard
    var exposure = 0.0
    var softHighlights = true
    init(profile:CameraLogProfile = .standard,exposure:Double = 0,softHighlights:Bool = true) { self.profile = profile; self.exposure = exposure; self.softHighlights = softHighlights }
    private enum CodingKeys:String,CodingKey { case profile,exposure,softHighlights }
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        self.init(profile:try c.decodeIfPresent(CameraLogProfile.self,forKey:.profile) ?? .standard,exposure:try c.decodeIfPresent(Double.self,forKey:.exposure) ?? 0,softHighlights:try c.decodeIfPresent(Bool.self,forKey:.softHighlights) ?? true)
        self = validated()
    }
    func validated() -> Self { var copy = self; copy.exposure = exposure.isFinite ? min(4,max(-4,exposure)) : 0; return copy }
}

/// Analytic input transform: no resampled 3D conversion table and no per-drag rebuild.
enum LogConversion {
    static func decode(_ code:Double,profile:CameraLogProfile = .appleLog) -> Double {
        if profile == .linearSRGB {return code}
        if profile == .encodedSRGB || profile == .encodedP3 {return code<=0.04045 ? code/12.92:pow((code+0.055)/1.055,2.4)}
        if profile == .canonLog3 { return 0.9 * (code < 0.097465473 ? -(pow(10,(0.12783901-code)/0.36726845)-1)/14.98325 : code <= 0.15277891 ? (code-0.12512219)/1.9754798 : (pow(10,(code-0.12240537)/0.36726845)-1)/14.98325) }
        if profile == .nikonNLog { return code*1023 < 452 ? pow(code*1023/650,3)-0.0075 : exp((code*1023-619)/150) }
        if profile == .fujiFLog2 { return code >= 0.100686685370811 ? (pow(10,(code-0.384316)/0.245281)-0.064829)/5.555556 : (code-0.092864)/8.799461 }
        if profile == .djiDLog { return code <= 0.14 ? (code-0.0929)/6.025 : (pow(10,(code-0.584555)/0.256663)-0.0108)/0.9892 }
        if profile == .sonySLog3Cine { return code >= 171.2102946929/1023 ? pow(10,(code*1023-420)/261.5)*0.19-0.01 : (code*1023-95)*0.01125/(171.2102946929-95) }
        if profile == .panasonicVLog { return code >= 0.181 ? pow(10,(code-0.598206)/0.241514)-0.00873 : (code-0.125)/5.6 }
        return code >= 0.20855531595464202 ? pow(2,(code-0.69336945)/0.08550479)-0.00964052 : sqrt(max(0,code)/47.28711236)-0.05641088
    }
    static func encode(_ linear:Double,profile:CameraLogProfile = .appleLog) -> Double {
        if profile == .linearSRGB {return linear}
        if profile == .encodedSRGB || profile == .encodedP3 {return linear<=0.0031308 ? linear*12.92:1.055*pow(linear,1/2.4)-0.055}
        if profile == .canonLog3 { let x=linear/0.9;return x < -0.014 ? -0.36726845*log10(-14.98325*x+1)+0.12783901 : x <= 0.014 ? 1.9754798*x+0.12512219 : 0.36726845*log10(14.98325*x+1)+0.12240537 }
        if profile == .nikonNLog { return linear < 0.328 ? 650*cbrt(linear+0.0075)/1023 : (150*log(linear)+619)/1023 }
        if profile == .fujiFLog2 { return linear >= 0.000889 ? 0.245281*log10(5.555556*linear+0.064829)+0.384316 : 8.799461*linear+0.092864 }
        if profile == .djiDLog { return linear <= 0.0078 ? 6.025*linear+0.0929 : log10(linear*0.9892+0.0108)*0.256663+0.584555 }
        if profile == .sonySLog3Cine { return linear >= 0.01125 ? (420+log10((linear+0.01)/0.19)*261.5)/1023 : (linear*(171.2102946929-95)/0.01125+95)/1023 }
        if profile == .panasonicVLog { return linear >= 0.01 ? 0.241514*log10(linear+0.00873)+0.598206 : 5.6*linear+0.125 }
        return linear >= 0.01 ? 0.08550479*log2(linear+0.00964052)+0.69336945 : linear >= -0.05641088 ? 47.28711236*pow(linear+0.05641088,2) : 0
    }
    private final class Compiled: @unchecked Sendable {
        let value:CIColorKernel?
        init() {
            let code = """
            float studioAppleLinear(float v, float profile) {
                if (profile > 5.5) return v <= 0.14 ? (v-0.0929)/6.025 : (pow(10.0,(v-0.584555)/0.256663)-0.0108)/0.9892;
                if (profile > 4.5) return v >= 0.100686685370811 ? (pow(10.0,(v-0.384316)/0.245281)-0.064829)/5.555556 : (v-0.092864)/8.799461;
                if (profile > 3.5) { float x=v*1023.0/650.0;return v*1023.0 < 452.0 ? x*x*x-0.0075 : exp((v*1023.0-619.0)/150.0); }
                if (profile > 2.5) return 0.9*(v < 0.097465473 ? -(pow(10.0,(0.12783901-v)/0.36726845)-1.0)/14.98325 : v <= 0.15277891 ? (v-0.12512219)/1.9754798 : (pow(10.0,(v-0.12240537)/0.36726845)-1.0)/14.98325);
                if (profile > 1.5) {
                    if (v >= 0.181) return pow(10.0,(v-0.598206)/0.241514)-0.00873;
                    return (v-0.125)/5.6;
                }
                if (profile > 0.5) {
                    if (v >= 171.2102946929/1023.0) return pow(10.0,(v*1023.0-420.0)/261.5)*0.19-0.01;
                    return (v*1023.0-95.0)*0.01125/(171.2102946929-95.0);
                }
                if (v >= 0.20855531595464202) return exp2((v-0.69336945)/0.08550479)-0.00964052;
                return sqrt(max(v,0.0)/47.28711236)-0.05641088;
            }
            kernel vec4 studioInput(__sample pixel, vec3 rowR, vec3 rowG, vec3 rowB, float exposure, float soft, float profile) {
                vec4 p = unpremultiply(pixel);
                if (p.a <= 0.000001) return vec4(0.0);
                vec3 linear = vec3(studioAppleLinear(p.r,profile),studioAppleLinear(p.g,profile),studioAppleLinear(p.b,profile));
                vec3 rgb = vec3(dot(linear,rowR),dot(linear,rowG),dot(linear,rowB))*exp2(exposure);
                if (soft > 0.5) {
                    float y = dot(rgb,vec3(0.2126,0.7152,0.0722));
                    if (y <= 0.0) rgb = vec3(0.0);
                    else {
                        float mapped = y <= 0.6 ? y : 0.6+0.4*(1.0-exp(-(y-0.6)/0.4));
                        rgb *= mapped/y;
                        vec3 chroma = rgb-vec3(mapped);
                        float low = min(chroma.r,min(chroma.g,chroma.b));
                        float high = max(chroma.r,max(chroma.g,chroma.b));
                        float strength = 1.0;
                        if (low < 0.0) strength = min(strength,mapped/-low);
                        if (high > 0.0) strength = min(strength,(1.0-mapped)/high);
                        rgb = vec3(mapped)+chroma*max(0.0,strength);
                    }
                }
                return premultiply(vec4(rgb,p.a));
            }
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;\nusing namespace coreimage;\n" + code.replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"kernel float4",with:"[[stitchable]] float4").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                if let kernels = try? CIKernel.kernels(withMetalString:metal), let kernel = kernels.first as? CIColorKernel { value = kernel; return }
            }
            value = CIColorKernel(source:code)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.value != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,input:InputConversion) -> CIImage {
        guard input.profile != .standard else { return source }
        if let space=input.profile.technicalColorSpace {
            let matched=source.matchedToWorkingSpace(from:space) ?? source
            return input.exposure==0 ? matched:matched.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:input.exposure])
        }
        let matrix = input.profile.matrix
        let rows = matrix.map { CIVector(x:$0[0],y:$0[1],z:$0[2]) }
        return compiled.value?.apply(extent:source.extent,arguments:[source,rows[0],rows[1],rows[2],input.exposure,input.softHighlights ? 1.0 : 0.0,input.profile.kernelIndex]) ?? source
    }
}
