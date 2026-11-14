#if DEBUG
import Foundation
import CoreImage
import ImageIO
import CryptoKit

enum PhotoDevelopmentVerification {
    static func check(_ yes:Bool,_ message:String) throws {if !yes {throw NSError(domain:"PhotoDevelopmentQA",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
    static func pixels(_ image:CIImage,_ x:Double=12,_ y:Double=20) -> [Float] {
        var p=[Float](repeating:0,count:4);ImageEngine.context().render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p
    }
    static func difference(_ a:CIImage,_ b:CIImage) -> Double {
        let x=RealMediaVerification.samples(a),y=RealMediaVerification.samples(b)
        guard x.count==y.count else {return 100}
        return zip(x,y).map {abs(Double($0-$1))}.reduce(0,+)/Double(x.count)
    }
    static func run() async throws -> [String:Any] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("PhotoDevelopmentQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let url=root.appendingPathComponent("original.png"),ctx=ImageEngine.context(),e=CGRect(x:0,y:0,width:64,height:48)
        let source=CIImage(color:CIColor(red:0.18,green:0.25,blue:0.32,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:e)
        try ctx.writePNGRepresentation(of:source,to:url,format:.RGBA8,colorSpace:ImageEngine.output)
        let data=try Data(contentsOf:url)
        var r=Recipe(),layer=LocalMask(kind:.subject)
        layer.automatic=try AutomaticMaskBitmap.make(CIImage(color:.white).cropped(to:CGRect(x:0,y:0,width:32,height:48)).composited(over:CIImage(color:.black).cropped(to:e)),recipe:r,videoStart:nil)
        r.masks=[layer];r.setCutout(layer.id,enabled:true)
        var bg=PhotoBackground();bg.mode = .solid;bg.red=0.7;bg.green=0.1;bg.blue=0.05;r.background=bg
        let rendered=ImageEngine.apply(source,recipe:r),left=pixels(rendered),right=pixels(rendered,52)
        try check(left[3]>0.99 && abs(left[0]-0.18)<0.01 && right[3]>0.99 && right[0]>right[1]*5,"Solid background or premultiplied foreground wrong")
        try check(!r.hasTransparentCutout,"Replacement forced transparent format")
        let output=try ImageEngine.export(source:url,recipe:r,format:.jpeg);defer {try? FileManager.default.removeItem(at:output.url)}
        try check(difference(try ImageEngine.open(output.url).image,rendered)<0.015,"Solid preview/export mismatch")
        let vault=ProjectVault(root:root.appendingPathComponent("vault"));var a=try await vault.importPhoto(url),b=try await vault.importPhoto(url)
        let back=root.appendingPathComponent("blue.png")
        try ctx.writePNGRepresentation(of:CIImage(color:CIColor(red:0.02,green:0.08,blue:0.8)).cropped(to:e),to:back,format:.RGBA8,colorSpace:ImageEngine.output)
        bg.asset=try await vault.importBackground(back,project:a);bg.mode = .image;r.background=bg;a.recipe=r;_ = try await vault.save(a)
        let reopened=try await vault.load().0.first(where:{$0.id==a.id})!
        try check(reopened.recipe==r,"Replacement persistence")
        let sourceURL=await vault.source(a),img=try ImageEngine.export(source:sourceURL,recipe:r,format:.png);defer {try? FileManager.default.removeItem(at:img.url)}
        let blue=pixels(try ImageEngine.open(img.url).image,52)
        try check(blue[2]>blue[0]*4 && blue[3]>0.99,"Replacement asset not loaded for full export")
        let cached=ImageEngine.apply(source,recipe:r)
        try check(difference(cached,try ImageEngine.open(img.url).image)<0.02,"Image replacement preview/export mismatch")
        BackgroundRendering.pin(bg.asset?.id)
        for _ in 0..<4 {_ = try await vault.importBackground(back,project:a)}
        let pinned=ImageEngine.apply(source,recipe:r)
        try check(pixels(pinned,52)[2]>pixels(pinned,52)[0]*4,"Thumbnail cache evicted the active replacement")
        BackgroundRendering.pin(nil)
        var missing=r;missing.background?.asset=nil
        do {_ = try ImageEngine.export(source:url,recipe:missing,format:.jpeg);throw StudioError.render} catch let err as NSError {try check(err.domain=="Background","Missing background silently exported")}
        b.recipe.exposure=0.3;_ = try await vault.save(b)
        let batch=try await BatchExportEngine.run([a,b],vault:vault,format:.jpeg,progress:{_,_,_ in});defer {try? FileManager.default.removeItem(at:batch.folder)}
        try check(batch.urls.count==2 && batch.failures.isEmpty && batch.urls.allSatisfy {$0.pathExtension=="jpg"},"Pool all export")
        let selected=try await BatchExportEngine.run([b],vault:vault,format:.png,progress:{_,_,_ in});defer {try? FileManager.default.removeItem(at:selected.folder)}
        try check(selected.urls.count==1 && selected.failures.isEmpty,"Pool selected export")
        var m=LocalMask(kind:.linear);m.exposure=0.3;m.tint=0.2;m.highlights=0.4;m.shadows=0.25;m.clarity=0.1;m.blur=0.1
        let adjusted=MaskEngine.apply(source,layers:[m]);try check(pixels(adjusted).allSatisfy(\.isFinite) && difference(adjusted,source)>0.01,"Local adjustments inactive")
        let spot=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:CGRect(x:29,y:21,width:6,height:6)).composited(over:source)
        let repaired=RetouchRendering.apply(spot,spots:[RetouchSpot(x:0.5,y:0.5,sourceX:0.2,sourceY:0.5,radius:0.15,kind:.clone)])
        try check(pixels(repaired,32,24)[0]<0.3 && pixels(spot,32,24)[0]>0.9,"Clone did not repair spot")
        let healed=RetouchRendering.apply(spot,spots:[RetouchSpot(x:0.5,y:0.5,sourceX:0.2,sourceY:0.5,radius:0.15,kind:.heal)])
        try check(pixels(healed,32,24).allSatisfy(\.isFinite) && pixels(healed,32,24)[0]<0.6 && abs(pixels(healed,32,24)[0]-pixels(source,32,24)[0])<0.02,"Heal failed")
        r.retouch=[RetouchSpot(x:0.5,y:0.5,sourceX:0.2,sourceY:0.5,radius:0.03,kind:.heal)];r.optics=PhotoOptics(chromatic:0.2,defringe:0.3);r.rawDevelopment=RawDevelopment();r.photoHDR=true
        let round=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r))
        try check(round==r && r.colorPreset.background==nil && r.colorPreset.rawDevelopment==nil && r.colorPreset.retouch==nil && r.colorPreset.optics==nil && r.colorPreset.photoHDR==nil,"Persistence/preset isolation")
        var lens=Recipe();lens.rawDevelopment=RawDevelopment();lens.rawDevelopment?.lensProfile=true
        try check(MaskFramingRepair.snapshot(MaskMotion.signature(lens))?.rawDevelopment?.lensProfile==true && !MaskFramingRepair.sameField(lens,Recipe()),"RAW lens mask geometry")
        try check(difference(PhotoRendering.optics(source,PhotoOptics()),source)<0.00001,"Neutral optics changed image")
        let high=CIImage(color:CIColor(red:3,green:2,blue:1,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:e)
        var hdrRecipe=Recipe();hdrRecipe.photoHDR=true
        let hdr=HDRPipeline.grade(high,recipe:hdrRecipe,hdr:true)
        try check(pixels(hdr)[0]>2.5 && pixels(PhotoRendering.sdr(hdr))[0]<=1.001,"HDR headroom/SDR proof")
        var hdrBG=a.recipe;hdrBG.photoHDR=true
        let hdrComposite=HDRPipeline.grade(high,recipe:hdrBG,hdr:true)
        try check(pixels(hdrComposite,52)[2]<1.01,"Foreground HDR headroom leaked into replacement")
        var heif:[String:Any]=["skipped":"Simulator encoder is not a physical HDR validation"]
        #if !targetEnvironment(simulator)
        let hdrURL=root.appendingPathComponent("hdr.heic")
        try ctx.writeHEIF10Representation(of:high,to:hdrURL,colorSpace:HDRPipeline.hlg,options:[:])
        let export=try ImageEngine.export(source:hdrURL,recipe:hdrRecipe,format:.hdrHEIF);defer {try? FileManager.default.removeItem(at:export.url)}
        let decoded=try ImageEngine.open(export.url,hdr:true)
        try check(pixels(decoded.image)[0]>1.2,"HLG HEIF headroom lost")
        let info=CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithURL(export.url as CFURL,nil)!,0,nil) as? [String:Any] ?? [:]
        try check(info[kCGImagePropertyGPSDictionary as String]==nil,"HDR privacy")
        heif=["passed":true,"headroom":pixels(decoded.image)[0],"width":export.width,"height":export.height,"properties":String(describing:info)]
        #endif
        var rawReport:[String:Any]=["skipped":"Explicit RAW fixture absent"]
        let fixtures=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("RealMediaQA")
        if let rawURL=(try? FileManager.default.contentsOfDirectory(at:fixtures,includingPropertiesForKeys:nil))?.first(where:{$0.pathExtension.lowercased()=="dng"}) {
            let original=SHA256.hash(data:try Data(contentsOf:rawURL)),base=try ImageEngine.open(rawURL,maxDimension:1600),cap=base.rawCapabilities!
            var settings=RawDevelopment();settings.temperature=max(2000,cap.temperature*0.7);settings.exposure=0.4;settings.recoverHighlights=true
            let edited=try ImageEngine.open(rawURL,maxDimension:1600,raw:settings)
            try check(difference(base.image,edited.image)>0.015,"RAW decode controls inactive")
            var rr=Recipe();rr.rawDevelopment=settings
            let exp=try ImageEngine.export(source:rawURL,recipe:rr,format:.jpeg);defer {try? FileManager.default.removeItem(at:exp.url)}
            let delta=difference(edited.image,try ImageEngine.open(exp.url,maxDimension:1600).image)
            try check(delta<0.05 && SHA256.hash(data:try Data(contentsOf:rawURL))==original,"RAW decode/export mismatch or original changed")
            rawReport=["passed":true,"previewExportMeanError":delta,"lensSupported":cap.lens,"highlightRecoverySupported":cap.recovery,"width":exp.width,"height":exp.height]
        }
        try check(try Data(contentsOf:url)==data,"Original modified")
        return ["passed":true,"solidReplacement":true,"imageReplacementPersistenceAndExport":true,"missingAssetGuard":true,"poolAllAndSelected":true,"richerLocalControls":true,"healClone":true,"presetIsolation":true,"hdrProofAndBackground":true,"heif":heif,"raw":rawReport]
    }
    @MainActor static func writeReport() async {
        let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("photo-development-verification.json")
        try? FileManager.default.removeItem(at:file)
        do {var report=try await Task.detached {try await run()}.value;report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;report["thermal"]=ProcessInfo.processInfo.thermalState.rawValue;try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:file,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:file,options:.atomic)}
    }
}
#endif
