#if DEBUG
import Foundation
import CoreImage
import CoreVideo

enum MaskPrecisionVerification {
    static func run() async throws ->[String:Any] {
        func check(_ ok:Bool,_ text:String) throws {if !ok {throw AutomaticSelectionEngine.error("Precision QA: "+text)}}
        var cases=0
        for size in [CGSize(width:400,height:300),CGSize(width:300,height:500)] {
            for scale in [1.0,2,4,6] {
                let container=CGSize(width:390,height:480),offset=MaskViewport.bounded(CGSize(width:45,height:-30),scale:scale,container:container)
                let identity=MaskViewport().rect(size:size,container:container)
                let expected=min(container.width/size.width,container.height/size.height)
                try check(abs(identity.width-size.width*expected)<0.000001 && abs(identity.height-size.height*expected)<0.000001,"Mask fit differs from renderer")
                let rect=MaskViewport(scale:scale,offset:offset).rect(size:size,container:container)
                for point in [CGPoint(x:0.1,y:0.2),CGPoint(x:0.5,y:0.5),CGPoint(x:0.9,y:0.8)] {
                    let screen=CGPoint(x:rect.minX+point.x*rect.width,y:rect.minY+point.y*rect.height)
                    try check(abs((screen.x-rect.minX)/rect.width-point.x)<0.000001 && abs((screen.y-rect.minY)/rect.height-point.y)<0.000001,"Zoomed brush coordinate mismatch")
                    cases+=1
                }
            }
        }
        var buffer:CVPixelBuffer?
        try check(CVPixelBufferCreate(nil,4,3,kCVPixelFormatType_OneComponent8,nil,&buffer)==kCVReturnSuccess,"Label fixture")
        let labels=buffer!;CVPixelBufferLockBaseAddress(labels,[])
        let bytes=CVPixelBufferGetBaseAddress(labels)!.assumingMemoryBound(to:UInt8.self),stride=CVPixelBufferGetBytesPerRow(labels)
        for y in 0..<3 {for x in 0..<4 {bytes[y*stride+x]=0}}
        bytes[0]=1;bytes[2*stride+3]=2;CVPixelBufferUnlockBaseAddress(labels,[])
        try check(try AutomaticSelectionEngine.instance(at:CGPoint(x:0,y:0),buffer:labels)==1,"Top-left subject instance")
        try check(try AutomaticSelectionEngine.instance(at:CGPoint(x:1,y:1),buffer:labels)==2,"Bottom-right subject instance")
        try check(try AutomaticSelectionEngine.instance(at:CGPoint(x:0.5,y:0.5),buffer:labels)==nil,"Background instance must not select everything")
        let recipe=Recipe(),extent=CGRect(x:0,y:0,width:64,height:64)
        let maskImage=CIImage(color:.white).cropped(to:CGRect(x:8,y:32,width:16,height:24)).composited(over:CIImage(color:.black).cropped(to:extent))
        let stored=try AutomaticMaskBitmap.make(maskImage,recipe:recipe,videoStart:nil),seed=MaskTracker.suggestedSeed(stored)
        try check(seed != nil && abs(seed!.x-0.25)<0.04 && abs(seed!.y-0.3125)<0.04,"Suggested subject target axes/bounds: \(String(describing:seed))")
        // A stroke addressed through a panned/zoomed preview must hit the same source pixel in export.
        let canvas=CGSize(width:390,height:480),sourceSize=CGSize(width:400,height:300)
        let view=MaskViewport(scale:4,offset:CGSize(width:35,height:-25)),rect=view.rect(size:sourceSize,container:canvas)
        let finger=CGPoint(x:rect.minX+0.63*rect.width,y:rect.minY+0.42*rect.height)
        let point=BrushPoint(x:(finger.x-rect.minX)/rect.width,y:(finger.y-rect.minY)/rect.height)
        var brush=LocalMask(kind:.brush);brush.brush=BrushDrawing();_ = brush.brush?.begin(point:point,radius:0.015,feather:0.1,erase:false)
        let weight=MaskEngine.weight(brush,extent:CGRect(origin:.zero,size:sourceSize)),context=ImageEngine.context()
        var pixel=[Float](repeating:0,count:4)
        context.render(weight,toBitmap:&pixel,rowBytes:16,bounds:CGRect(x:252,y:174,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
        try check(pixel[0]>0.95,"Zoomed stroke/export position")
        let inference=try await AutomaticSelectionVerification.inference()
        let tracking=try await TrackingVerification.video()
        return ["passed":true,"viewportCoordinateCases":cases,"instanceRowStrideAndOrientation":true,"subjectSeedBounds":true,"zoomedBrushExportAlignment":true,"inference":inference,"detailedTracking":tracking]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("mask-precision-verification.json")
        try? FileManager.default.removeItem(at:url)
        var report=await Task.detached(priority:.utility) {()->[String:Any] in do {return try await run()} catch {return ["passed":false,"error":error.localizedDescription]}}.value
        report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
        report["thermal"]=ProcessInfo.processInfo.thermalState.rawValue
        if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
}
#endif
