#if DEBUG
import CoreImage
import Foundation

enum MaskPoseVerification {
    static func run() async throws ->[String:Any] {
        func check(_ b:Bool,_ s:String) throws {if !b {throw NSError(domain:"MaskPoseQA",code:1,userInfo:[NSLocalizedDescriptionKey:s])}}
        _ = try TrackingVerification.math()
        let recipe=Recipe(),signature=MaskMotion.signature(recipe)
        var motion=MaskMotion(framing:signature,start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:2,x:0.2,y:0)],pivotX:0.5,pivotY:0.5,sourceWidth:160,sourceHeight:100)
        motion.setCorrection(time:2,x:0.1,y:0,tolerance:0.001,scale:2,rotation:90)
        try check(motion.corrections?.count==2 && motion.validCorrections && motion.isValid,"Bounded pose points")
        let middle=motion.pose(at:1)
        try check(abs(middle.scale-1.5)<1e-10 && abs(middle.rotation-45)<1e-10,"Pose interpolation")
        try check(motion.pose(at:-1).scale==1 && motion.pose(at:3).rotation==90,"Held pose ends")
        motion.setCorrection(time:2,x:0.2,y:0,tolerance:0.001)
        try check(motion.pose(at:2).scale==2 && motion.pose(at:2).rotation==90,"Moving point erased pose")
        motion.setCorrection(time:2,x:2,y:0,tolerance:0.001,scale:1.5)
        try check(motion.correction(at:2).x==2 && motion.pose(at:2).rotation==90,"Pose clamped a reframed translation")
        motion.setCorrection(time:2,x:0,y:0,tolerance:0.001,scale:1,rotation:90)
        let extent=CGRect(x:0,y:0,width:160,height:100),pivot=CGPoint(x:80,y:50)
        let turn=motion.affine(at:2,extent:extent,center:CGPoint(x:0.5,y:0.5))
        let right=CGPoint(x:90,y:50).applying(turn)
        try check(abs(right.x-112)<1e-9 && abs(right.y-40)<1e-9,"Clockwise turn/pivot/translation")
        var radial=LocalMask(kind:.radial);radial.width=0.2;radial.height=0.05;radial.feather=0.1
        var stationary=motion;stationary.points=[.init(time:0,x:0,y:0),.init(time:2,x:0,y:0)];radial.motion=stationary
        let context=ImageEngine.context()
        func sample(_ image:CIImage,_ x:Double,_ y:Double)->Float {var v=[Float](repeating:0,count:4);context.render(image,toBitmap:&v,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return v[0]}
        let mask=MaskMotion.$frame.withValue(.init(time:2,framing:signature)){MaskEngine.weight(radial,extent:extent)}
        try check(sample(mask,80,70)>0.9 && sample(mask,100,50)<0.01,"Rendered radial rotation")
        let neutral=try JSONDecoder().decode(MaskMotion.self,from:Data("{\"framing\":\"x\",\"start\":0,\"end\":2,\"points\":[{\"time\":0,\"x\":0,\"y\":0},{\"time\":2,\"x\":0,\"y\":0}],\"corrections\":[{\"time\":1,\"x\":0.1,\"y\":0}]}".utf8))
        try check(neutral.pose(at:1).scale==1 && neutral.pose(at:1).rotation==0 && neutral.pivotX==nil,"Legacy neutral pose")
        let data=try JSONEncoder().encode(motion),roundtrip=try JSONDecoder().decode(MaskMotion.self,from:data)
        try check(roundtrip==motion,"Pose persistence")
        var bad=motion;bad.corrections=[.init(time:1,x:0,y:0,scale:0)];let clean=try JSONDecoder().decode(MaskMotion.self,from:JSONEncoder().encode(bad));try check(clean.corrections==nil,"Invalid scale")
        bad=motion;bad.pivotX = .nan
        let safe=bad.affine(at:2,extent:extent,center:pivot);try check(safe == .identity,"Invalid affine escaped to Core Image")
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("PoseCrop-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let source=root.appendingPathComponent("source.png"),full=CGRect(x:0,y:0,width:100,height:120)
        try context.writePNGRepresentation(of:CIImage(color:.gray).cropped(to:full),to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        let shape=CIImage(color:.white).cropped(to:CGRect(x:45,y:35,width:40,height:65)).composited(over:CIImage(color:.black).cropped(to:full))
        var before=Recipe(),automatic=LocalMask(kind:.subject)
        automatic.automatic=try AutomaticMaskBitmap.make(shape,recipe:before,videoStart:nil);automatic.exposure=1
        automatic.motion=MaskMotion(framing:MaskMotion.signature(before),start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:2,x:0,y:0)],pivotX:0.6,pivotY:0.4,sourceWidth:100,sourceHeight:120)
        automatic.motion?.setCorrection(time:0,x:0.1,y:0.05,tolerance:0.001,scale:1.4,rotation:35);before.masks=[automatic]
        let original=MaskMotion.$frame.withValue(.init(time:0,framing:MaskMotion.signature(before))){MaskEngine.weight(before.masks[0],extent:full)}
        var cropped=before;cropped.crop = .square;cropped.geometry.cropScale=0.6
        let inference=AutomaticSelectionEngine.analysisCount
        let repaired=try await MaskFramingRepair.repair(recipe:cropped,url:source,video:nil,prepared:nil)
        try MaskMotion.validateExport(repaired,duration:2)
        try check(repaired.masks[0].motion?.pose(at:0).scale==1.4 && repaired.masks[0].motion?.pose(at:0).rotation==35,"Crop lost pose")
        let frame=PhotoFraming.window(in:full.size,recipe:cropped),local=CGRect(origin:.zero,size:frame.size)
        let prepared=try AutomaticMaskBitmap.prepare(repaired)
        let current=AutomaticMaskBitmap.$prepared.withValue(prepared){MaskMotion.$frame.withValue(.init(time:0,framing:MaskMotion.signature(cropped))){MaskEngine.weight(repaired.masks[0],extent:local)}}
        var error:Float=0
        for x in stride(from:5.0,to:55.0,by:10) {for y in stride(from:5.0,to:55.0,by:10) {error=max(error,abs(sample(current,x,y)-sample(original,x+frame.minX,y+frame.minY)))}}
        try check(error<0.03 && AutomaticSelectionEngine.analysisCount==inference,"Crop/pose pixels or inference: \(error)")
        return ["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","interpolationPivotClockwise":true,"legacyNeutral":true,"invalidData":true,"persistence":true,"cropPoseMaxError":error,"cropNoInference":true,"renderedRotation":true,"bounded32":true]
    }
    @MainActor static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("mask-pose-verification.json")
        do {let r=try await Task.detached(priority:.utility){try await run()}.value;try JSONSerialization.data(withJSONObject:r,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
