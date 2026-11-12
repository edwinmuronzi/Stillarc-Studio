#if DEBUG
import Foundation
import CoreImage
import ImageIO

enum CutoutHistoryVerification {
    static func check(_ yes:Bool,_ text:String) throws {if !yes {throw NSError(domain:"CutoutHistoryQA",code:1,userInfo:[NSLocalizedDescriptionKey:text])}}
    static func cutout() async throws -> [String:Any] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("CutoutQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let source=root.appendingPathComponent("source.png"),e=CGRect(x:0,y:0,width:64,height:48),context=ImageEngine.context()
        let image=CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:e)
        try context.writePNGRepresentation(of:image,to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        let original=try Data(contentsOf:source)
        let matte=CIFilter(name:"CILinearGradient",parameters:["inputPoint0":CIVector(x:28,y:0),"inputPoint1":CIVector(x:36,y:0),"inputColor0":CIColor.white,"inputColor1":CIColor.black])!.outputImage!.cropped(to:e)
        var r=Recipe(),layer=LocalMask(kind:.subject);layer.automatic=try AutomaticMaskBitmap.make(matte,recipe:r,videoStart:nil);r.masks=[layer];r.setCutout(layer.id,enabled:true)
        func rgba(_ image:CIImage,_ x:Int) -> [Float] {var p=[Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:20,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p}
        let shown=ImageEngine.apply(image,recipe:r)
        try check(rgba(shown,12)[3]>0.99 && rgba(shown,52).allSatisfy {abs($0)<0.001} && abs(rgba(shown,31)[3]-0.56)<0.08,"Cutout alpha/soft edge/premultiplication")
        var partial=r;partial.masks[0].amount=0.5
        try check(abs(rgba(ImageEngine.apply(image,recipe:partial),52)[3]-0.5)<0.01,"Cutout strength")
        partial.masks[0].amount=0
        try check(!partial.hasCutout && rgba(ImageEngine.apply(image,recipe:partial),52)[3]>0.99,"Zero strength bypass")
        var inverse=r;inverse.masks[0].inverted=true
        try check(rgba(ImageEngine.apply(image,recipe:inverse),12)[3]<0.01 && rgba(ImageEngine.apply(image,recipe:inverse),52)[3]>0.99,"Invert cutout")
        let output=try ImageEngine.export(source:source,recipe:r,format:.png);defer {try? FileManager.default.removeItem(at:output.url)}
        let decoded=try ImageEngine.open(output.url),props=CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithURL(output.url as CFURL,nil)!,0,nil) as? [CFString:Any]
        try check(props?[kCGImagePropertyHasAlpha] as? Bool==true && output.width==64 && output.height==48 && rgba(decoded.image,52)[3]<0.01 && rgba(decoded.image,12)[3]>0.99,"Transparent PNG full-size roundtrip")
        do {_ = try ImageEngine.export(source:source,recipe:r,format:.jpeg);throw StudioError.render} catch let e as NSError {try check(e.domain=="Cutout","JPEG silently flattened")}
        let encoded=try JSONEncoder().encode(r),loaded=try JSONDecoder().decode(Recipe.self,from:encoded)
        try check(loaded==r && loaded.hasCutout && !r.colorPreset.hasCutout,"Cutout persistence/preset isolation")
        var stale=r;stale.crop = .square
        try check(rgba(ImageEngine.apply(image,recipe:stale,preview:true),40)[3]>0.99,"Stale preview became empty")
        let repaired=try await MaskFramingRepair.repair(recipe:stale,url:source,video:nil,prepared:nil)
        var edited=stale;edited.masks[0].exposure=0.5;edited.masks[0].cutout=false
        let merged=MaskFramingRepair.merge(repaired,snapshot:stale,current:edited)
        try check(merged[0].exposure==0.5 && merged[0].cutout==false && merged[0].automatic==repaired.masks[0].automatic,"Crop repair overwrote live edits")
        let cropped=try ImageEngine.export(source:source,recipe:repaired,format:.png);defer {try? FileManager.default.removeItem(at:cropped.url)}
        try check(cropped.width==48 && cropped.height==48,"Cropped cutout export")
        let vault=ProjectVault(root:root.appendingPathComponent("vault"));var a=try await vault.importPhoto(source);let b=try await vault.importPhoto(source);a.recipe=r;_ = try await vault.save(a)
        let batch=try await BatchExportEngine.run([a,b],vault:vault,format:.jpeg,progress:{_,_,_ in});defer {try? FileManager.default.removeItem(at:batch.folder)}
        try check(batch.failures.isEmpty && batch.urls.map(\.pathExtension)==["png","jpg"],"Mixed batch lost alpha or wrong filename extension")
        try check(try Data(contentsOf:source)==original,"Original changed")
        #if !targetEnvironment(simulator)
        let realSource=Bundle.main.url(forResource:"Sample",withExtension:"jpg")!,input=try await AutomaticSelectionEngine.input(url:realSource,video:nil,recipe:Recipe())
        let before=AutomaticSelectionEngine.analysisCount,detected=try await AutomaticSelectionEngine.analyze(input,kind:.subject,recipe:Recipe(),videoStart:nil)
        var real=Recipe(),subject=LocalMask(kind:.subject);subject.automatic=detected;real.masks=[subject];real.setCutout(subject.id,enabled:true)
        let file=try ImageEngine.export(source:realSource,recipe:real,format:.png);defer {try? FileManager.default.removeItem(at:file.url)}
        let opened=try ImageEngine.open(file.url,maxDimension:1024),extent=opened.image.extent
        var sky=[Float](repeating:0,count:4);context.render(opened.image,toBitmap:&sky,rowBytes:16,bounds:CGRect(x:extent.width*0.5,y:extent.height*0.8,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
        try check(sky[3]<0.1 && AutomaticSelectionEngine.analysisCount==before+1,"Native foreground cutout/inference count")
        #endif
        return ["passed":true,"transparentPNG":true,"softAlphaPremultiplication":true,"strengthAndInvert":true,"cropRepair":true,"mixedBatch":true,"sourcePreserved":true,"presetIsolation":true]
    }
    @MainActor static func history() async throws -> [String:Any] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("HistoryQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let source=root.appendingPathComponent("source.png"),e=CGRect(x:0,y:0,width:64,height:48)
        try ImageEngine.context().writePNGRepresentation(of:CIImage(color:.gray).cropped(to:e),to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        let vault=ProjectVault(root:root.appendingPathComponent("vault")),library=StudioLibrary(vault:vault)
        var a=try await vault.importPhoto(source),b=try await vault.importPhoto(source),c=try await vault.importPhoto(source)
        b.recipe.crop = .square;c.recipe.geometry.lensDistortion=0.1
        _ = try await vault.save(b);_ = try await vault.save(c);await library.load()
        let pool=EditingPool(projects:library.projects,persist:false)!
        let first=a.recipe;a.recipe.exposure=0.8;_ = await library.save(a)
        pool.recordEdit(id:a.id,before:first,after:a.recipe)
        let clip=AdjustmentClipboard(name:"Grade",recipe:a.recipe,sections:[.light]);var changes=[PoolHistoryChange]()
        for p in [b,c] {let result=try await vault.pasteCopiedAdjustments(p.id,clipboard:clip,sections:[.light]);changes.append(.init(id:p.id,before:p.recipe,after:result.recipe,sections:[.light]))}
        pool.record(.init(title:"Sync edits",changes:changes))
        try await pool.moveHistory(undo:true,library:library)
        let undone=try await vault.load().0
        try check(undone.first(where:{$0.id==a.id})?.recipe.exposure==0.8 && undone.filter {$0.id != a.id}.allSatisfy {$0.recipe.exposure==0},"Undo did not reverse the complete sync")
        try await pool.moveHistory(undo:true,library:library)
        try check(try await vault.load().0.first(where:{$0.id==a.id})?.recipe==first,"Undo chronological source edit")
        try await pool.moveHistory(undo:false,library:library);try await pool.moveHistory(undo:false,library:library)
        let redone=try await vault.load().0
        try check(redone.allSatisfy {$0.recipe.exposure==0.8} && redone.first(where:{$0.id==b.id})?.recipe.crop == .square && redone.first(where:{$0.id==c.id})?.recipe.geometry.lensDistortion==0.1,"Redo/source settings")
        try await pool.moveHistory(undo:true,library:library)
        pool.recordEdit(id:a.id,before:a.recipe,after:first);try check(pool.redoHistory.isEmpty,"New edit did not clear redo")
        let invalid=PoolHistoryStep(title:"Missing",changes:[changes[0],.init(id:UUID(),before:Recipe(),after:Recipe())])
        let snapshot=try await vault.load().0
        do {_ = try await vault.applyPoolHistory(invalid,undo:false);throw StudioError.render} catch let error as NSError {try check(error.domain==NSCocoaErrorDomain && error.code==NSFileReadNoSuchFileError,"Missing preflight")}
        let final=try await vault.load().0
        try check(snapshot==final,"Preflight failure partially applied history")
        var staleSave=a;staleSave.recipe.exposure = -2
        let canceled=Task {try await vault.saveEditorSnapshot(staleSave)};canceled.cancel()
        do {_ = try await canceled.value;throw StudioError.render} catch is CancellationError {}
        try check(try await vault.load().0==final,"Canceled autosave overwrote history")
        return ["passed":true,"wholeSyncUndoRedo":true,"chronologicalLocalEdits":true,"redoInvalidation":true,"sourceSettingsPreserved":true,"missingProjectPreflight":true,"cancelledSaveIsolation":true]
    }
    @MainActor static func writeReport() async {
        let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("cutout-history-verification.json")
        try? FileManager.default.removeItem(at:file)
        do {let pixels=try await Task.detached {try await cutout()}.value;let edits=try await history();let r:[String:Any]=["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","cutout":pixels,"history":edits,"thermal":ProcessInfo.processInfo.thermalState.rawValue];try JSONSerialization.data(withJSONObject:r,options:.prettyPrinted).write(to:file,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:file,options:.atomic)}
    }
}
#endif
