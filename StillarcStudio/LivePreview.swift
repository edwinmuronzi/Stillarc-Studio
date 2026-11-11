import SwiftUI
import MetalKit
import CoreImage

struct LivePreview: UIViewRepresentable {
    let source: CIImage
    let recipe: Recipe
    var signalSource: CIImage? = nil
    let original: Bool
    var rangePreview: ColorRange? = nil
    var active: Bool = true
    var hdr = false
    var scopes:ScopeSampler? = nil
    func makeCoordinator() -> Renderer { Renderer() }
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.isPaused = true; view.enableSetNeedsDisplay = true
        view.framebufferOnly = false; view.colorPixelFormat = hdr ? .rgba16Float : .bgra8Unorm
        view.backgroundColor = .clear; view.isOpaque = true
        view.clearColor = MTLClearColorMake(0.025,0.03,0.04,1)
        view.contentScaleFactor = min(view.traitCollection.displayScale, 2)
        (view.layer as? CAMetalLayer)?.colorspace = ImageEngine.output
        view.delegate = context.coordinator
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        view.colorPixelFormat = hdr ? .rgba16Float : .bgra8Unorm
        (view.layer as? CAMetalLayer)?.colorspace = hdr ? ImageEngine.working : ImageEngine.output
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = hdr
        context.coordinator.update(source, signalSource:signalSource,recipe: recipe, original: original, rangePreview: rangePreview, active: active, hdr:hdr, scopes:scopes, view: view)
    }
    static func dismantleUIView(_ view: MTKView, coordinator: Renderer) { view.delegate = nil; coordinator.clear() }
    @MainActor final class Renderer: NSObject, MTKViewDelegate {
        let device = MTLCreateSystemDefaultDevice()
        lazy var commands = device?.makeCommandQueue()
        lazy var context = device.map { CIContext(mtlDevice: $0, options: [.workingColorSpace: ImageEngine.working, .cacheIntermediates: false]) }
        private var source: CIImage?
        private var recipe = Recipe()
        private var signalSource:CIImage?
        private var original = false
        private var hdr = false
        private var scopes:ScopeSampler?
        private var rangePreview: ColorRange?
        private var active = true
        private var dirty = true
        private var drawing = false
        func clear() { source = nil; context?.clearCaches() }
        func update(_ source:CIImage,signalSource:CIImage?,recipe: Recipe, original: Bool, rangePreview: ColorRange?, active: Bool, hdr:Bool, scopes:ScopeSampler?, view: MTKView) {
            let changed = self.source !== source || self.signalSource !== signalSource || self.recipe != recipe || self.original != original || self.rangePreview != rangePreview || self.active != active || self.hdr != hdr || self.scopes !== scopes
            self.source = source; self.signalSource = signalSource; self.recipe = recipe; self.original = original; self.rangePreview = rangePreview; self.active = active;self.hdr = hdr;self.scopes = scopes
            guard changed else { return }; dirty = true
            if active && !drawing { view.setNeedsDisplay() }
        }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { dirty = true; if active && !drawing { view.setNeedsDisplay() } }
        func draw(in view: MTKView) {
            guard active, dirty, !drawing, let source, let context, let command = commands?.makeCommandBuffer(), let drawable = view.currentDrawable else { return }
            let size = view.drawableSize; guard size.width > 0 && size.height > 0 else { return }
            drawing = true; dirty = false
            let began = CACurrentMediaTime()
            var originalRecipe = Recipe(); originalRecipe.copyFraming(from: recipe)
            let image = HDRPipeline.grade(!original && recipe.input.profile != .standard ? (signalSource ?? source) : source, recipe: original ? originalRecipe : recipe, hdr:hdr, rangePreview: original ? nil : rangePreview)
            scopes?.offer(image,hdr:hdr)
            let scale = min(size.width / image.extent.width, size.height / image.extent.height)
            let placed = image.transformed(by: .init(scaleX: scale,y: scale)).transformed(by: .init(translationX: (size.width-image.extent.width*scale)/2, y: (size.height-image.extent.height*scale)/2))
            let background = CIImage(color: CIColor(red: 0.025, green: 0.03, blue: 0.04)).cropped(to: CGRect(origin: .zero,size: size))
            context.render(placed.composited(over: background), to: drawable.texture, commandBuffer: command, bounds: CGRect(origin: .zero,size: size), colorSpace: hdr ? ImageEngine.working : ImageEngine.output)
            command.addCompletedHandler { [weak self, weak view] buffer in
                let ms = (CACurrentMediaTime() - began) * 1000
                DispatchQueue.main.async {
                    #if DEBUG
                    PreviewMetrics.shared.record(ms: ms, failed: buffer.status == .error)
                    #endif
                    guard let self, let view else { return }
                    self.drawing = false
                    if self.dirty && self.active { view.setNeedsDisplay() }
                }
            }
            command.present(drawable); command.commit()
        }
    }
}
#if DEBUG
@MainActor final class PreviewMetrics {
    static let shared = PreviewMetrics()
    var times: [Double] = []
    var failures = 0
    func record(ms: Double, failed: Bool) { times.append(ms); if failed { failures += 1 } }
}
#endif
