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
        let source = GradingKernelSource.code
        var note = "Dynamic libraries are not supported by this GPU"
        if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
            let metalSource = """
            #include <metal_stdlib>
            #include <CoreImage/CoreImage.h>
            using namespace metal;
            using namespace coreimage;
            float wrapSix(float x, float period) { return x-floor(x/period)*period; }
            float3 wrapSix(float3 x, float period) { return x-floor(x/period)*period; }
            """ + "\n" + source.replacingOccurrences(of:"vec2",with:"float2").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"vec4",with:"float4")
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
    static func applySelective(_ image: CIImage, adjustments: SelectiveColors, wheels: ColorWheels = ColorWheels(), mixer: ChannelMixer = ChannelMixer(), warp:ColorWarp? = nil, previewRange: ColorRange? = nil) -> CIImage {
        let warp=(warp ?? ColorWarp()).validated()
        guard !warp.isNeutral || !adjustments.isNeutral || !wheels.isNeutral || !mixer.isNeutral || previewRange != nil, let kernel = kernel.value else { return image }
        let vectors = ColorRange.allCases.map { band -> CIVector in
            let a = adjustments[keyPath:band.key]
            return CIVector(x:a.hue/60,y:a.saturation,z:a.brightness)
        }
        let wheelVectors = WheelZone.allCases.map { zone -> CIVector in
            let wheel = wheels[keyPath:zone.key], tint = wheel.tint
            return CIVector(x:tint[0],y:tint[1],z:tint[2],w:wheel.exposure)
        }
        let rows = MixerChannel.allCases.map { channel -> CIVector in
            let keys = channel.keys
            return CIVector(x:mixer[keyPath:keys[0]],y:mixer[keyPath:keys[1]],z:mixer[keyPath:keys[2]],w:mixer[keyPath:channel.offsetKey])
        }
        var arguments: [Any] = [image]+vectors.map { $0 as Any }+[Double(previewRange?.rawValue ?? -1)]
        arguments += wheelVectors.map { $0 as Any }
        arguments += [CIVector(x:wheels.balance,y:wheels.blend)]
        arguments += rows.map { $0 as Any }
        arguments += [CIVector(x:wheels.isNeutral ? 0 : 1,y:mixer.isNeutral ? 0 : 1,z:mixer.monochrome ? 1 : 0,w:wheels.preserveBrightness ? 1 : 0), adjustments.isNeutral ? 0.0 : 1.0]
        for i in 0..<4 {
            let p=i<warp.points.count ? warp.points[i] : ColorWarpPoint()
            let on=i<warp.points.count && !p.isNeutral
            arguments += [CIVector(x:p.hue/60,y:p.saturation,z:on ? p.hueShift/60*warp.amount:0,w:on ? p.saturationShift*warp.amount:0),CIVector(x:p.hueWidth/60,y:p.saturationWidth)]
        }
        arguments += [warp.isNeutral ? 0.0:1.0]
        return kernel.apply(extent:image.extent,arguments:arguments) ?? image
    }
    // First compile happens on the import/decode worker, not during the first slider gesture.
    private static let prepared: Bool = {
        guard available else { return false }
        let source = CIImage(color:CIColor(red:0.3,green:0.1,blue:0.05)).cropped(to:CGRect(x:0,y:0,width:2,height:2))
        var adjustment = SelectiveColors(); adjustment.red.hue = 2
        var curves = RGBCurves(); curves.red.middle = 0.55
        var wheels = ColorWheels(); wheels.shadows.hue = 220; wheels.shadows.strength = 0.1
        var mixer = ChannelMixer(); mixer.redGreen = 0.05
        let image = applySelective(applyCurves(source,curves:curves),adjustments:adjustment,wheels:wheels,mixer:mixer)
        return ImageEngine.context().createCGImage(image,from:image.extent) != nil
    }()
    static func prepare() throws { guard prepared else { throw StudioError.render } }
}
