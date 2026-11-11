import CoreImage
import CoreImage.CIFilterBuiltins
import Metal

// Tiny 1D float tables, not full-image CPU transforms or a rebuilt 3D LUT per drag.
enum ColorPipeline {
    private final class CurveCache: @unchecked Sendable {
        let lock = NSLock()
        var entries: [(RGBCurves,Data)] = []
        func data(for curves: RGBCurves) -> Data {
            lock.lock()
            if let cached = entries.first(where: { $0.0 == curves })?.1 { lock.unlock(); return cached }
            lock.unlock()
            let master = CurveSpline(curves.master)
            let channels = [CurveSpline(curves.red),CurveSpline(curves.green),CurveSpline(curves.blue)]
            var samples = [Float](); samples.reserveCapacity(1024*3)
            for n in 0..<1024 {
                let input = master.value(at:Double(n)/1023)
                for channel in channels { samples.append(Float(channel.value(at:input))) }
            }
            let data = samples.withUnsafeBytes { Data($0) }
            lock.lock(); entries.append((curves,data)); if entries.count > 8 { entries.removeFirst() }; lock.unlock()
            return data
        }
    }
    private static let cache = CurveCache()
    static func applyCurves(_ image: CIImage, curves: RGBCurves) -> CIImage {
        guard !curves.isNeutral else { return image }
        let filter = CIFilter.colorCurves()
        filter.inputImage = image
        filter.curvesData = cache.data(for:curves)
        filter.curvesDomain = CIVector(x:0,y:1)
        filter.colorSpace = ImageEngine.output
        return filter.outputImage ?? image
    }
    private final class Kernel: @unchecked Sendable {
        let value: CIColorKernel?
        let backend: String
        let compilationNote: String
        init() {
        let source = """
        float encodeComponent(float x) { return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(max(x,0.0),1.0/2.4)-0.055; }
        float decodeComponent(float x) { return x <= 0.04045 ? x / 12.92 : pow((x+0.055)/1.055,2.4); }
        float rangeWeight(float hue, float center, float leftWidth, float rightWidth) {
            float distance = mod(hue-center+9.0,6.0)-3.0;
            float width = distance < 0.0 ? leftWidth : rightWidth;
            return 1.0-smoothstep(0.0,width,abs(distance));
        }
        kernel vec4 studioSelective(__sample pixel, vec3 red, vec3 orange, vec3 yellow, vec3 green,
                                    vec3 aqua, vec3 blue, vec3 purple, vec3 magenta, float previewRange) {
            vec4 original = unpremultiply(pixel);
            vec3 encoded = vec3(encodeComponent(original.r),encodeComponent(original.g),encodeComponent(original.b));
            float low = min(encoded.r,min(encoded.g,encoded.b));
            float high = max(encoded.r,max(encoded.g,encoded.b));
            float offset = min(0.0,low);
            float span = max(1.0,high-offset);
            vec3 rgb = (encoded-vec3(offset))/span;
            float maximum = (high-offset)/span;
            float minimum = (low-offset)/span;
            float chroma = maximum-minimum;
            float hue = 0.0;
            if (chroma > 0.00001) {
                if (maximum == rgb.r) hue = (rgb.g-rgb.b)/chroma;
                else if (maximum == rgb.g) hue = 2.0+(rgb.b-rgb.r)/chroma;
                else hue = 4.0+(rgb.r-rgb.g)/chroma;
                hue = mod(hue+6.0,6.0);
            }
            float w0 = rangeWeight(hue,0.0,1.0,0.5);
            float w1 = rangeWeight(hue,0.5,0.5,0.5);
            float w2 = rangeWeight(hue,1.0,0.5,1.0);
            float w3 = rangeWeight(hue,2.0,1.0,1.0);
            float w4 = rangeWeight(hue,3.0,1.0,1.0);
            float w5 = rangeWeight(hue,4.0,1.0,0.5);
            float w6 = rangeWeight(hue,4.5,0.5,0.5);
            float w7 = rangeWeight(hue,5.0,0.5,1.0);
            float chromaGate = smoothstep(0.0,0.08,chroma);
            vec3 change = (red*w0+orange*w1+yellow*w2+green*w3+aqua*w4+blue*w5+purple*w6+magenta*w7)*chromaGate;
            if (dot(abs(change),vec3(1.0)) > 0.000001 && chroma > 0.00001) {
                float lightness = (maximum+minimum)*0.5;
                float saturation = chroma/max(0.00001,1.0-abs(2.0*lightness-1.0));
                hue += change.x;
                saturation = clamp(saturation*(1.0+change.y),0.0,1.0);
                lightness = clamp(lightness+change.z*0.25,0.0,1.0);
                float adjustedChroma = (1.0-abs(2.0*lightness-1.0))*saturation;
                vec3 shape = clamp(abs(mod(vec3(hue)+vec3(0.0,4.0,2.0),6.0)-vec3(3.0))-vec3(1.0),0.0,1.0);
                encoded = (vec3(lightness)+adjustedChroma*(shape-vec3(0.5)))*span+vec3(offset);
            }
            if (previewRange > -0.5) {
                float weight = w0;
                if (previewRange > 0.5) weight = w1;
                if (previewRange > 1.5) weight = w2;
                if (previewRange > 2.5) weight = w3;
                if (previewRange > 3.5) weight = w4;
                if (previewRange > 4.5) weight = w5;
                if (previewRange > 5.5) weight = w6;
                if (previewRange > 6.5) weight = w7;
                float gray = dot(encoded,vec3(0.2126,0.7152,0.0722))*0.35;
                encoded = mix(vec3(gray),encoded,weight*chromaGate);
            } else if (dot(abs(change),vec3(1.0)) <= 0.000001) { return pixel; }
            vec3 linear = vec3(decodeComponent(encoded.r),decodeComponent(encoded.g),decodeComponent(encoded.b));
            return premultiply(vec4(linear,original.a));
        }
        """
        var note = "Dynamic libraries are not supported by this GPU"
        if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
            let metalSource = """
            #include <metal_stdlib>
            #include <CoreImage/CoreImage.h>
            using namespace metal;
            using namespace coreimage;
            float wrapSix(float x, float period) { return x-floor(x/period)*period; }
            float3 wrapSix(float3 x, float period) { return x-floor(x/period)*period; }
            """ + "\n" + source.replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"vec4",with:"float4")
                .replacingOccurrences(of:"kernel float4",with:"[[stitchable]] float4")
                .replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                .replacingOccurrences(of:"mod(",with:"wrapSix(")
            do {
                let kernels = try CIKernel.kernels(withMetalString:metalSource)
                if let compiled = kernels.first as? CIColorKernel {
                    value = compiled; backend = "Metal stitchable"; compilationNote = "Ready"; return
                }
                note = "Compiler did not return a color kernel"
            } catch { note = error.localizedDescription }
        }
        // Compatibility for older Metal devices without dynamic library support.
        value = CIColorKernel(source:source); backend = "Core Image portable"; compilationNote = note
        }
    }
    private static let kernel = Kernel()
    static var backend: String { kernel.backend }
    static var compilationNote: String { kernel.compilationNote }
    static var available: Bool { kernel.value != nil }
    static func applySelective(_ image: CIImage, adjustments: SelectiveColors, previewRange: ColorRange? = nil) -> CIImage {
        guard !adjustments.isNeutral || previewRange != nil, let kernel = kernel.value else { return image }
        let vectors = ColorRange.allCases.map { band -> CIVector in
            let a = adjustments[keyPath:band.key]
            return CIVector(x:a.hue/60,y:a.saturation,z:a.brightness)
        }
        return kernel.apply(extent:image.extent,arguments:[image]+vectors.map { $0 as Any }+[Double(previewRange?.rawValue ?? -1)]) ?? image
    }
    // First compile happens on the import/decode worker, not during the first slider gesture.
    private static let prepared: Bool = {
        guard available else { return false }
        let source = CIImage(color:CIColor(red:0.3,green:0.1,blue:0.05)).cropped(to:CGRect(x:0,y:0,width:2,height:2))
        var adjustment = SelectiveColors(); adjustment.red.hue = 2
        var curves = RGBCurves(); curves.red.middle = 0.55
        let image = applySelective(applyCurves(source,curves:curves),adjustments:adjustment)
        return ImageEngine.context().createCGImage(image,from:image.extent) != nil
    }()
    static func prepare() throws { guard prepared else { throw StudioError.render } }
}
