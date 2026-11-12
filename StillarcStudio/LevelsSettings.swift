import CoreImage
import Metal

enum LevelsRendering {
    private final class Compiled:@unchecked Sendable {
        let kernel:CIColorKernel?
        init() {
            let code = """
            kernel vec4 studioLevels(__sample source, float black, float white, float gamma, float floor, float ceiling) {
                vec4 p = unpremultiply(source);
                float peak = max(1.0,max(p.r,max(p.g,p.b)));
                vec3 c = clamp((p.rgb/peak-vec3(black))/max(0.01,white-black),0.0,1.0);
                c = pow(c,vec3(1.0/gamma));
                return premultiply(vec4((vec3(floor)+c*(ceiling-floor))*peak,p.a));
            }
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n"+code.replacingOccurrences(of:"kernel vec4",with:"[[stitchable]] float4").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                if let k = try? CIKernel.kernels(withMetalString:metal).first as? CIColorKernel { kernel = k;return }
            }
            kernel = CIColorKernel(source:code)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.kernel != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,recipe:Recipe) -> CIImage {
        guard recipe.levelBlack != 0 || recipe.levelWhite != 1 || recipe.levelGamma != 1 || recipe.levelOutputBlack != 0 || recipe.levelOutputWhite != 1 else { return source }
        let r = recipe.validated()
        return compiled.kernel?.apply(extent:source.extent,arguments:[source,r.levelBlack,r.levelWhite,r.levelGamma,r.levelOutputBlack,r.levelOutputWhite]) ?? source
    }
}
