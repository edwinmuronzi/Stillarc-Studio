import CoreImage
import CoreGraphics
import QuartzCore

extension Notification.Name { static let studioBrushReady = Notification.Name("StudioBrushReady") }

/// Bitmap work stays off the UI actor. Preview requests coalesce; export renders exact vectors synchronously on its worker.
enum BrushMaskRasterizer {
    final class Raster {
        let width:Int,height:Int
        let context:CGContext
        var drawing:BrushDrawing?
        init?(width:Int,height:Int,highPrecision:Bool = false) {
            self.width = width;self.height = height
            let bits = highPrecision ? 16 : 8
            guard let c = CGContext(data:nil,width:width,height:height,bitsPerComponent:bits,bytesPerRow:0,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return nil }
            context = c
        }
        func render(_ next:BrushDrawing) -> CGImage? {
            guard !Task.isCancelled else { return nil }
            var incremental = false,oldPoints = 0,oldCount = 0
            if let previous = drawing,previous.strokes.count>0,next.strokes.count>=previous.strokes.count {
                oldCount = previous.strokes.count
                if Array(previous.strokes.dropLast()) == Array(next.strokes.prefix(oldCount-1)),let old = previous.strokes.last {
                    let current = next.strokes[oldCount-1]
                    incremental = old.id == current.id && old.radius == current.radius && old.feather == current.feather && old.erase == current.erase && current.points.starts(with:old.points)
                    oldPoints = old.points.count
                }
            }
            if !incremental { context.setFillColor(gray:0,alpha:1);context.fill(CGRect(x:0,y:0,width:width,height:height));oldCount = 0;oldPoints = 0 }
            for index in max(0,oldCount-1)..<next.strokes.count {
                let stroke = next.strokes[index]
                let start = incremental && index == oldCount-1 ? oldPoints : 0
                paint(stroke,startingAt:start)
                if Task.isCancelled { return nil }
            }
            drawing = next
            return context.makeImage()
        }
        private func paint(_ stroke:BrushStroke,startingAt start:Int) {
            guard !stroke.points.isEmpty else { return }
            let radius = max(0.5,stroke.radius*Double(min(width,height))),inner = radius*(1-stroke.feather)
            let color:CGFloat = stroke.erase ? 0 : 1
            guard let gradient = CGGradient(colorSpace:CGColorSpaceCreateDeviceGray(),colorComponents:[color,1,color,0],locations:[0,1],count:2) else { return }
            func point(_ p:BrushPoint) -> CGPoint { CGPoint(x:p.x*Double(width),y:(1-p.y)*Double(height)) }
            func stamp(_ p:CGPoint) { context.drawRadialGradient(gradient,startCenter:p,startRadius:inner,endCenter:p,endRadius:radius,options:.drawsBeforeStartLocation) }
            if start == 0 { stamp(point(stroke.points[0])) }
            for index in max(1,start)..<stroke.points.count {
                let a = point(stroke.points[index-1]),b = point(stroke.points[index]),distance = hypot(b.x-a.x,b.y-a.y)
                let count = max(1,Int(ceil(distance/max(0.5,radius*0.2))))
                for n in 1...count { if n%64 == 0 && Task.isCancelled { return };let f = Double(n)/Double(count);stamp(CGPoint(x:a.x+(b.x-a.x)*f,y:a.y+(b.y-a.y)*f)) }
            }
        }
    }
    private struct Request { let drawing:BrushDrawing;let width:Int;let height:Int }
    private struct Snapshot { let revision:UUID;let width:Int;let height:Int;let image:CGImage }
    private final class Cache:@unchecked Sendable {
        let lock = NSLock(),queue = DispatchQueue(label:"Studio.BrushRaster",qos:.userInitiated)
        #if DEBUG
        var jobs = 0,incrementalJobs = 0
        var durations = [Double]()
        #endif
        var snapshots = [UUID:Snapshot](),pending = [UUID:Request](),working = Set<UUID>()
        // Accessed only by queue.
        var rasters = [UUID:Raster](),order = [UUID]()
        func request(_ request:Request) -> CGImage? {
            lock.lock()
            let id = request.drawing.id,snapshot = snapshots[id]
            if snapshot?.revision == request.drawing.revision && snapshot?.width == request.width && snapshot?.height == request.height { lock.unlock();return snapshot?.image }
            pending[id] = request
            let launch = working.insert(id).inserted
            lock.unlock()
            if launch { queue.async { self.process(id) } }
            return snapshot?.image
        }
        func process(_ id:UUID) {
            lock.lock();let request = pending.removeValue(forKey:id)
            let ready = request.map { snapshots[id]?.revision == $0.drawing.revision && snapshots[id]?.width == $0.width && snapshots[id]?.height == $0.height } ?? false
            lock.unlock()
            if let request,!ready {
                let began = CACurrentMediaTime()
                let wasIncremental = rasters[id]?.drawing != nil && rasters[id]?.width == request.width && rasters[id]?.height == request.height
                let raster:Raster?
                if let old = rasters[id],old.width == request.width && old.height == request.height { raster = old }
                else { raster = Raster(width:request.width,height:request.height);rasters[id] = raster }
                if let image = raster?.render(request.drawing) {
                    lock.lock();
                    #if DEBUG
                    jobs += 1;if wasIncremental { incrementalJobs += 1 };if durations.count<20000 { durations.append((CACurrentMediaTime()-began)*1000) }
                    #endif
                    snapshots[id] = Snapshot(revision:request.drawing.revision,width:request.width,height:request.height,image:image);lock.unlock()
                    order.removeAll { $0 == id };order.append(id)
                    while order.count>8 { let old = order.removeFirst();rasters.removeValue(forKey:old);lock.lock();snapshots.removeValue(forKey:old);lock.unlock() }
                    DispatchQueue.main.async { NotificationCenter.default.post(name:.studioBrushReady,object:id) }
                }
            }
            lock.lock();let again = pending[id] != nil;if !again { working.remove(id) };lock.unlock()
            if again { queue.async { self.process(id) } }
        }
    }
    struct ExportKey:Hashable { let id:UUID;let revision:UUID }
    final class PreparedExport:@unchecked Sendable {
        let images:[ExportKey:CGImage]
        init(_ images:[ExportKey:CGImage]) { self.images = images }
    }
    @TaskLocal static var preparedExport:PreparedExport?
    static func prepareExport(layers:[LocalMask],extent:CGRect) throws -> PreparedExport {
        var images = [ExportKey:CGImage]()
        for layer in layers.prefix(4) where layer.kind == .brush && layer.hasEffect {
            guard let drawing = layer.brush,!drawing.strokes.isEmpty else { continue }
            try Task.checkCancellation()
            let key = ExportKey(id:drawing.id,revision:drawing.revision)
            if images[key] != nil { continue }
            guard let image = Raster(width:max(1,Int(extent.width.rounded())),height:max(1,Int(extent.height.rounded())),highPrecision:true)?.render(drawing) else { try Task.checkCancellation();throw StudioError.render }
            images[key] = image
        }
        return PreparedExport(images)
    }
    private static let cache = Cache()
    #if DEBUG
    static func statistics() -> [String:Double] {
        cache.lock.lock();defer { cache.lock.unlock() }
        let times = cache.durations.sorted()
        return ["jobs":Double(cache.jobs),"reusedRasterJobs":Double(cache.incrementalJobs),"p95Milliseconds":times.isEmpty ? 0 : times[min(times.count-1,Int(Double(times.count)*0.95))],"queued":Double(cache.pending.count+cache.working.count)]
    }
    #endif
    static func image(_ drawing:BrushDrawing?,extent:CGRect,preview:Bool) -> CIImage {
        guard let drawing,!drawing.strokes.isEmpty else { return CIImage(color:.black).cropped(to:extent) }
        let scale = preview ? min(1,768/max(extent.width,extent.height)) : 1
        let w = max(1,Int((extent.width*scale).rounded())),h = max(1,Int((extent.height*scale).rounded()))
        let cg:CGImage?
        if preview { cg = cache.request(Request(drawing:drawing,width:w,height:h)) }
        else if let preparedExport { cg = preparedExport.images[ExportKey(id:drawing.id,revision:drawing.revision)] }
        else { cg = Raster(width:w,height:h,highPrecision:true)?.render(drawing) }
        guard let cg else { return CIImage(color:.black).cropped(to:extent) }
        return CIImage(cgImage:cg,options:[.colorSpace:NSNull()]).transformed(by:.init(scaleX:extent.width/Double(cg.width),y:extent.height/Double(cg.height))).transformed(by:.init(translationX:extent.minX,y:extent.minY)).cropped(to:extent)
    }
}
