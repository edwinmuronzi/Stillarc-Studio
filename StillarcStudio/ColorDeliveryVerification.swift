#if DEBUG
import Foundation
import CoreImage
import ImageIO
import AVFoundation

enum ColorDeliveryVerification {
    static func run() async throws ->[String:Any] {
        func check(_ value:Bool,_ message:String) throws {if !value {throw NSError(domain:"ColorDeliveryQA",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        let context=ImageEngine.context()
        func solid(_ rgb:[CGFloat],alpha:CGFloat=1)->CIImage {CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:1600,height:1200))}
        func pixel(_ image:CIImage)->[Float] {var v=[Float](repeating:0,count:4);context.render(image,toBitmap:&v,rowBytes:16,bounds:CGRect(x:image.extent.midX,y:image.extent.midY,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output);return v}
        func error(_ a:[Float],_ b:[Float])->Float {zip(a,b).map {abs($0-$1)}.max() ?? 99}
        try ColorPipeline.prepare()
        let red=solid([1,0.2,0.2]),gray=solid([0.4,0.4,0.4]),blue=solid([0.2,0.2,1])
        var point=ColorWarpPoint();point.hue=0;point.saturation=1;point.hueShift=60;point.saturationShift = -0.25
        var warp=ColorWarp();warp.points=[point]
        func apply(_ x:CIImage,_ w:ColorWarp)->CIImage {ColorPipeline.applySelective(x,adjustments:SelectiveColors(),warp:w)}
        try check(error(pixel(apply(red,ColorWarp())),pixel(red))<0.00001,"Neutral warp changed pixels")
        let result=pixel(apply(red,warp));try check(error(result,[0.9,0.9,0.3,1])<0.008,"HSL center mapping \(result)")
        try check(error(pixel(apply(gray,warp)),pixel(gray))<0.00001,"Warp tinted gray")
        try check(error(pixel(apply(blue,warp)),pixel(blue))<0.00001,"Warp altered outside reach")
        var wrapped=warp;wrapped.points[0].hue=360
        try check(error(pixel(apply(red,wrapped)),result)<0.00001,"Hue seam discontinuity")
        var half=warp;half.amount=0.5
        try check(error(pixel(apply(red,half)),[0.95,0.6,0.25,1])<0.008,"Strength mapping")
        var zero=warp;zero.amount=0
        try check(error(pixel(apply(red,zero)),pixel(red))<0.00001,"Zero strength not bypassed")
        let alpha=pixel(apply(solid([1,0.2,0.2],alpha:0.4),warp));try check(abs(alpha[3]-0.4)<0.001 && alpha.allSatisfy(\.isFinite),"Premultiplied alpha")
        var invalid=point;invalid.hue = .nan;invalid.hueWidth=0;invalid.saturationWidth = .infinity;invalid.hueShift = 999
        var invalidWarp=warp;invalidWarp.points=Array(repeating:invalid,count:8);invalidWarp.amount = .nan
        let bounded=invalidWarp.validated();try check(bounded.points.count==1 && bounded.points[0].hueShift==60 && bounded.points[0].hueWidth==5 && bounded.amount==1,"Validation/duplicate bounds")
        var recipe=Recipe();recipe.colorWarp=warp
        let encoded=try JSONEncoder().encode(recipe),decoded=try JSONDecoder().decode(Recipe.self,from:encoded)
        try check(decoded==recipe && PresetDocument(name:"Warp",recipe:recipe.colorPreset).schema==5,"Recipe/preset roundtrip")
        let pasted=Recipe().pasting(recipe,sections:[.color]);try check(pasted.colorWarp==warp && Recipe().pasting(recipe,sections:[.light]).colorWarp==nil,"Color transfer isolation")
        var reset=recipe;reset.reset(.color);try check(reset.colorWarp==nil && recipe.hasAdjustments(in:.color),"Reset and edit dot")
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("ColorDelivery-\(UUID())")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:folder)}
        let original=folder.appendingPathComponent("source.png");try context.writePNGRepresentation(of:red,to:original,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes=try Data(contentsOf:original)
        let delivery=DeliverySettings(size:.small,quality:.balanced)
        try check(delivery.dimensions(CGSize(width:800,height:600)) == CGSize(width:800,height:600),"Unwanted upscale")
        try check(delivery.dimensions(CGSize(width:1600,height:1200)) == CGSize(width:1280,height:960),"Photo size")
        try check(delivery.dimensions(CGSize(width:1921,height:1081),video:true).width.truncatingRemainder(dividingBy:2)==0,"Video even dimension")
        let suite="StudioDeliveryQA-\(UUID())";let defaults=UserDefaults(suiteName:suite)!
        defaults.removePersistentDomain(forName:suite);delivery.save(defaults);try check(DeliverySettings.load(defaults)==delivery,"Remembered delivery");defaults.removePersistentDomain(forName:suite)
        var exportChecks=0
        for format in [ExportFormat.png,.jpeg,.hdrHEIF] {
            let output=try ImageEngine.export(source:original,recipe:recipe,format:format,delivery:delivery);defer {try? FileManager.default.removeItem(at:output.url)}
            try check(output.width==1280 && output.height==960,"Photo export size \(format)")
            let read=try ImageEngine.open(output.url,maxDimension:1280,hdr:format == .hdrHEIF)
            try check(pixel(read.image).allSatisfy(\.isFinite),"Export finite \(format)")
            if format != .hdrHEIF {try check(error(pixel(read.image),result)<0.02,"Warp preview/export mismatch \(format)")}
            exportChecks+=1
        }
        var transparent=recipe;let matte=LocalMask(kind:.radial);transparent.masks=[matte];transparent.masks[0].cutout=true
        let alphaOut=try ImageEngine.export(source:original,recipe:transparent,format:.png,delivery:delivery);defer {try? FileManager.default.removeItem(at:alphaOut.url)}
        let alphaImage=try ImageEngine.open(alphaOut.url,maxDimension:1280)
        var edge=[Float](repeating:0,count:4);context.render(alphaImage.image,toBitmap:&edge,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
        try check(edge[3]<0.01,"Resized PNG transparency lost")
        let lut=try ColorLUTExport.make(recipe:recipe,dimension:33,name:"Warp")
        try check(error(pixel(lut.apply(red,amount:1)),result)<0.03,"Color warp missing from LUT")
        let movie=try await VideoFixtures.make(profile:.standard,frames:8,audioTracks:1,width:2560,height:1440);defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        let descriptor=try await VideoEngine.describe(movie)
        var vr=recipe;vr.video.start=0.1
        let video=try await VideoEngine.export(source:movie,descriptor:descriptor,recipe:vr,delivery:delivery,progress:{_ in});defer {try? FileManager.default.removeItem(at:video.url)}
        let out=try await VideoEngine.describe(video.url),audio=try await AVURLAsset(url:video.url).loadTracks(withMediaType:.audio)
        try check(out.width==1280 && out.height==720 && audio.count==1 && abs(out.duration-(descriptor.duration-0.1))<0.04,"Resized trimmed video/audio")
        let vault=ProjectVault(root:folder.appendingPathComponent("vault"))
        var photo=try await vault.importPhoto(original);photo.recipe=recipe;_ = try await vault.save(photo)
        let batch=try await BatchExportEngine.run([photo],vault:vault,format:.png,delivery:delivery,progress:{_,_,_ in})
        defer {try? FileManager.default.removeItem(at:batch.folder)}
        let batchImage=try ImageEngine.open(batch.urls[0],maxDimension:nil)
        try check(batch.failures.isEmpty && batchImage.width==1280 && batchImage.height==960 && error(pixel(batchImage.image),result)<0.02,"Pool delivery settings/grade")
        try check(try Data(contentsOf:original)==bytes,"Original changed")
        return ["passed":true,"warpCenterAndReach":true,"grayAndHueSeam":true,"strengthAndAlpha":true,"validationAndPersistence":true,"presetSchema5AndTransfer":true,"photoFormats":exportChecks,"transparentPNG":true,"LUTExport":true,"poolDelivery":true,"video":["width":out.width,"height":out.height,"audioTracks":audio.count,"duration":out.duration],"sourcePreserved":true]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("color-delivery-verification.json")
        try? FileManager.default.removeItem(at:url)
        let result=await Task.detached(priority:.utility) {()->[String:Any] in
            do {return try await run()} catch {return ["passed":false,"error":error.localizedDescription]}
        }.value
        var report=result;report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;report["thermal"]=ProcessInfo.processInfo.thermalState.rawValue
        if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted) {try? data.write(to:url,options:.atomic)}
    }
}
#endif
