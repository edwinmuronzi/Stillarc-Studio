import CoreImage
import Metal

/// One per-pixel GPU selection; no CPU image readback, bitmap scans or per-frame LUT construction.
enum RangeMaskKernel {
    private final class Compiled: @unchecked Sendable {
        let kernel: CIColorKernel?
        init() {
            let code = """
            kernel vec4 studioRangeMask(__sample pixel, float mode, float target, float radius, float saturation, float low, float high, float soft) {
                vec4 p = unpremultiply(pixel);
                vec3 c = max(p.rgb,vec3(0.0));
                float hi = max(c.r,max(c.g,c.b));
                float lo = min(c.r,min(c.g,c.b));
                float delta = hi-lo;
                float hue = 0.0;
                if (delta > 0.000001) {
                    if (hi == c.r) { hue = (c.g-c.b)/delta; }
                    else if (hi == c.g) { hue = 2.0+(c.b-c.r)/delta; }
                    else { hue = 4.0+(c.r-c.g)/delta; }
                    hue = fract(hue/6.0+1.0);
                }
                float distance = abs(hue-target);
                distance = min(distance,1.0-distance);
                float sat = delta/max(hi,0.000001);
                float weight = 0.0;
                if (mode < 0.5) {
                    float edge = max(0.001,soft*radius);
                    weight = (1.0-smoothstep(max(0.0,radius-edge),radius,distance))*smoothstep(max(0.0,saturation-0.05),max(0.001,saturation),sat);
                    if (radius >= 0.5) { weight = smoothstep(max(0.0,saturation-0.05),max(0.001,saturation),sat); }
                } else {
                    float brightness = sqrt(clamp(dot(c,vec3(0.2126,0.7152,0.0722)),0.0,1.0));
                    float a = smoothstep(low-soft,low,brightness);
                    float b = 1.0-smoothstep(high,high+soft,brightness);
                    weight = a*b;
                }
                weight *= step(0.000001,p.a);
                return vec4(weight,weight,weight,1.0);
            }
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n" + code.replacingOccurrences(of:"kernel vec4",with:"[[stitchable]] float4").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                if let result = try? CIKernel.kernels(withMetalString:metal).first as? CIColorKernel { kernel = result;return }
            }
            kernel = CIColorKernel(source:code)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.kernel != nil else { throw StudioError.render } }
    static func image(_ source:CIImage,layer:LocalMask) -> CIImage {
        let s = (layer.selection ?? MaskSelection()).validated()
        return compiled.kernel?.apply(extent:source.extent,arguments:[source,layer.kind == .color ? 0.0 : 1.0,s.hue/360,s.tolerance/360,s.minimumSaturation,s.lower,s.upper,s.softness]) ?? CIImage(color:.black).cropped(to:source.extent)
    }
}
