import CoreImage
import Vision

/// Request-only object identity association. Instance numbers are local to each frame.
/// A fresh soft silhouette is saved per source frame; no model runs during playback.
final class ObjectVideoMatteTracker {
    struct LabelMap {
        struct Region {var count=0;var minX=Int.max;var minY=Int.max;var maxX=0;var maxY=0}
        let width:Int,height:Int
        let labels:[UInt8]
        let regions:[Int:Region]
        init(buffer:CVPixelBuffer) throws {
            guard CVPixelBufferGetPixelFormatType(buffer)==kCVPixelFormatType_OneComponent8 else {throw AutomaticSelectionEngine.error("This device returned an unsupported object map.")}
            width=CVPixelBufferGetWidth(buffer);height=CVPixelBufferGetHeight(buffer)
            guard width>0,height>0,width<=2048,height<=2048 else {throw StudioError.render}
            CVPixelBufferLockBaseAddress(buffer,.readOnly);defer {CVPixelBufferUnlockBaseAddress(buffer,.readOnly)}
            guard let address=CVPixelBufferGetBaseAddress(buffer) else {throw StudioError.render}
            let data=address.assumingMemoryBound(to:UInt8.self),stride=CVPixelBufferGetBytesPerRow(buffer)
            var pixels=[UInt8](repeating:0,count:width*height),found=[Int:Region]()
            for y in 0..<height {for x in 0..<width {
                let id=Int(data[y*stride+x]);pixels[y*width+x]=UInt8(id)
                if id != 0 {var r=found[id] ?? Region();r.count+=1;r.minX=min(r.minX,x);r.minY=min(r.minY,y);r.maxX=max(r.maxX,x);r.maxY=max(r.maxY,y);found[id]=r}
            }}
            labels=pixels;regions=found
        }
        // UI and label-map coordinates both start at the top left.
        func instance(at point:CGPoint)->Int? {
            guard point.x.isFinite,point.y.isFinite,(0...1).contains(point.x),(0...1).contains(point.y) else {return nil}
            let x=min(width-1,Int(point.x*Double(width))),y=min(height-1,Int(point.y*Double(height)))
            let id=Int(labels[y*width+x]);return id==0 ? nil:id
        }
        func rect(_ id:Int)->CGRect? {
            guard let r=regions[id] else {return nil}
            return CGRect(x:Double(r.minX)/Double(width),y:Double(r.minY)/Double(height),width:Double(r.maxX-r.minX+1)/Double(width),height:Double(r.maxY-r.minY+1)/Double(height))
        }
        func contains(_ point:CGPoint,id:Int)->Bool {
            guard point.x>=0,point.y>=0,point.x<1,point.y<1 else {return false}
            return Int(labels[min(height-1,Int(point.y*Double(height)))*width+min(width-1,Int(point.x*Double(width)))])==id
        }
    }
    private let segment=VNGenerateForegroundInstanceMaskRequest()
    private let sequence=VNSequenceRequestHandler()
    private var tracking:VNTrackObjectRequest?
    private var previous:LabelMap?
    private var previousID:Int?
    private let point:CGPoint
    init(point:CGPoint) {self.point=point;segment.preferBackgroundProcessing=true}
    static func visionRect(_ topLeft:CGRect)->CGRect {CGRect(x:topLeft.minX,y:1-topLeft.maxY,width:topLeft.width,height:topLeft.height)}
    static func overlap(_ a:CGRect,_ b:CGRect)->Double {
        let i=a.intersection(b);guard !i.isNull else {return 0}
        let intersection=i.width*i.height
        return intersection/max(0.000001,a.width*a.height+b.width*b.height-intersection)
    }
    static func select(current:LabelMap,previous:LabelMap,id:Int,predicted:CGRect,minimumScore:Double=0.25) throws ->Int {
        guard let old=previous.rect(id),predicted.width>0,predicted.height>0 else {throw StudioError.render}
        var intersections=[Int:Int](),expected=0
        for y in 0..<current.height {for x in 0..<current.width {
            let p=CGPoint(x:(Double(x)+0.5)/Double(current.width),y:(Double(y)+0.5)/Double(current.height))
            guard predicted.contains(p) else {continue}
            let mapped=CGPoint(x:old.minX+(p.x-predicted.minX)/predicted.width*old.width,y:old.minY+(p.y-predicted.minY)/predicted.height*old.height)
            if previous.contains(mapped,id:id) {expected+=1;let label=Int(current.labels[y*current.width+x]);if label != 0 {intersections[label,default:0]+=1}}
        }}
        guard expected>0 else {throw lost()}
        let scores=current.regions.compactMap {label,region -> (Int,Double)? in
            guard let box=current.rect(label) else {return nil}
            let intersection=intersections[label] ?? 0,ratio=Double(region.count)/Double(expected)
            guard (0.4...2.5).contains(ratio) else {return nil}
            let shape=Double(intersection)/Double(max(1,expected+region.count-intersection))
            let score=0.55*shape+0.45*overlap(box,predicted)
            return (label,score)
        }.sorted {$0.1>$1.1}
        guard let best=scores.first,best.1>=minimumScore,(scores.count==1 || best.1-scores[1].1>=0.12) else {
            #if DEBUG
            VerificationProgress.record("Object association rejected: predicted=\(predicted), expected=\(expected), scores=\(scores.prefix(3))")
            #endif
            throw lost()
        }
        return best.0
    }
    static func lost()->NSError {AutomaticSelectionEngine.error("The selected object was lost or became ambiguous. No new matte was saved. Shorten the kept clip before the obstruction, choose a clearer object, or start a new selection after it returns.")}
    func mask(_ image:CGImage) throws ->CIImage {
        try Task.checkCancellation()
        var predicted:CGRect?,trackingReliable=false
        if let previous,let previousID {predicted=previous.rect(previousID)}
        if let tracking {
            try sequence.perform([tracking],on:image,orientation:.up)
            if let observation=tracking.results?.first as? VNDetectedObjectObservation,observation.confidence>=0.45 {
                let box=observation.boundingBox
                if box.minX>=0,box.maxX<=1,box.minY>=0,box.maxY<=1 {predicted=Self.visionRect(box);trackingReliable=true}
            }
            // If the box tracker loses confidence, a stricter fresh-mask overlap may
            // still establish continuity for a visible, slowly moving object. Never
            // use an unverified box prediction as the saved silhouette.
        }
        let handler=VNImageRequestHandler(cgImage:image,orientation:.up)
        try handler.perform([segment]);try Task.checkCancellation()
        guard let observation=segment.results?.first,!observation.allInstances.isEmpty else {
            #if DEBUG
            VerificationProgress.record("Object segmentation returned no foreground instances")
            #endif
            if previous == nil {throw AutomaticSelectionEngine.error("No distinct foreground object was detected on the first frame. Try a closer, clearer object with more separation from its background.")}
            throw Self.lost()
        }
        let map=try LabelMap(buffer:observation.instanceMask),selected:Int
        if let previous,let previousID,let predicted {
            if trackingReliable,let matched=try? Self.select(current:map,previous:previous,id:previousID,predicted:predicted) {selected=matched}
            else if let last=previous.rect(previousID) {selected=try Self.select(current:map,previous:previous,id:previousID,predicted:last,minimumScore:0.5)}
            else {throw Self.lost()}
        }
        else {guard let first=map.instance(at:point) else {throw AutomaticSelectionEngine.error("Tap inside a distinct foreground object, away from its edge, and try again. Nothing was saved.")};selected=first}
        guard observation.allInstances.contains(selected),let box=map.rect(selected) else {throw Self.lost()}
        let buffer=try observation.generateScaledMaskForImage(forInstances:IndexSet(integer:selected),from:handler)
        let next=VNDetectedObjectObservation(boundingBox:Self.visionRect(box))
        if let tracking {tracking.inputObservation=next}
        else {let request=VNTrackObjectRequest(detectedObjectObservation:next);request.trackingLevel = .accurate;request.preferBackgroundProcessing=true;tracking=request}
        previous=map;previousID=selected
        return CIImage(cvPixelBuffer:buffer,options:[.colorSpace:NSNull()])
    }
}
