import CoreImage
import Metal

enum LensRendering {
    private final class Compiled:@unchecked Sendable {
        let kernel:CIWarpKernel?
        init() {
            let body = """
                vec2 q = POSITION-center;
                float r2 = dot(q,q)/max(1.0,radius2);
                return center+q*(1.0+strength*r2)/max(1.0,1.0+strength);
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let source = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n[[stitchable]] float2 studioLens(float2 center,float radius2,float strength,destination dest) {"+body.replacingOccurrences(of:"vec2",with:"float2").replacingOccurrences(of:"POSITION",with:"dest.coord()")+"}"
                if let kernel = try? CIKernel.kernels(withMetalString:source).first as? CIWarpKernel { self.kernel = kernel;return }
            }
            kernel = CIWarpKernel(source:"kernel vec2 studioLens(vec2 center,float radius2,float strength) {"+body.replacingOccurrences(of:"POSITION",with:"destCoord()")+"}")
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.kernel != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,strength:Double) -> CIImage {
        guard abs(strength)>0.000001 else { return source }
        let k = min(0.25,max(-0.25,strength)),e = source.extent
        let padding = abs(k)*max(e.width,e.height)+2
        return compiled.kernel?.apply(extent:e,roiCallback:{ _,rect in rect.insetBy(dx:-padding,dy:-padding).intersection(e) },image:source,arguments:[CIVector(x:e.midX,y:e.midY),(e.width*e.width+e.height*e.height)/4,k]) ?? source
    }
}
