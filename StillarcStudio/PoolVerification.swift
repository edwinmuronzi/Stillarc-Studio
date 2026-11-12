#if DEBUG
import Foundation
import CoreImage

enum PoolVerification {
    static func check(_ condition:Bool,_ text:String) throws {if !condition {throw NSError(domain:"PoolQA",code:1,userInfo:[NSLocalizedDescriptionKey:text])}}
    static func matte(recipe:Recipe) throws -> AutomaticMask {
        let extent=CGRect(x:0,y:0,width:64,height:48)
        let image=CIImage(color:.white).cropped(to:CGRect(x:0,y:0,width:32,height:48)).composited(over:CIImage(color:.black).cropped(to:extent))
        return try AutomaticMaskBitmap.make(image,recipe:recipe,videoStart:nil)
    }
    static func run() async throws -> [String:Any] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("PoolQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let source=root.appendingPathComponent("source.png"),context=ImageEngine.context(),extent=CGRect(x:0,y:0,width:64,height:48)
        let image=CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        try context.writePNGRepresentation(of:image,to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        let vault=ProjectVault(root:root.appendingPathComponent("vault"))
        var a=try await vault.importPhoto(source),b=try await vault.importPhoto(source),c=try await vault.importPhoto(source)
        b.recipe.crop = .square;b.recipe.geometry.lensDistortion=0.1;b.recipe.input.exposure=0.2
        let stored=try matte(recipe:b.recipe);_ = try b.recipe.addSubjectBackground(stored)
        _ = try await vault.save(b);let previous=b.recipe
        let state=EditingPoolState(ids:[c.id,a.id,b.id,a.id,UUID()],active:UUID(),selected:[a.id,b.id,UUID()])
        let valid=state.available([a,b,c])!
        try check(valid.ids==[c.id,a.id,b.id] && valid.active==c.id && valid.selected==[a.id,b.id],"Pool order/pruning/selection")
        try check(try JSONDecoder().decode(EditingPoolState.self,from:JSONEncoder().encode(valid))==valid,"Pool restore")
        a.recipe.exposure=0.7;a.recipe.halation=0.2
        let clipboard=AdjustmentClipboard(name:"Pool grade",recipe:a.recipe,sections:Set(AdjustmentSection.allCases))
        let synced=try await vault.pasteCopiedAdjustments(b.id,clipboard:clipboard,sections:[.light,.texture])
        try check(synced.recipe.exposure==0.7 && synced.recipe.halation==0.2 && synced.recipe.masks==previous.masks && synced.recipe.crop==previous.crop && synced.recipe.geometry==previous.geometry && synced.recipe.input==previous.input,"Pool selective sync isolation")
        let version=synced.versions!.last!,restored=try await vault.loadVersion(synced,version:version)
        try check(restored==previous,"Before-sync recovery")
        let unchanged=try await vault.pasteCopiedAdjustments(b.id,clipboard:clipboard,sections:[.light,.texture])
        try check(unchanged.versions?.count==synced.versions?.count,"Unchanged sync created history")
        let untouched=try await vault.load().0.first(where:{$0.id==c.id})
        try check(untouched?.recipe==c.recipe,"Unselected project changed")
        var pair=Recipe();let shared=try matte(recipe:pair);_ = try pair.addSubjectBackground(shared)
        try check(pair.masks.count==2 && pair.masks[0].automatic?.id==pair.masks[1].automatic?.id && pair.masks[1].inverted,"Pair did not share a matte")
        pair.masks[0].exposure=1;pair.masks[1].exposure = -1
        let rendered=ImageEngine.apply(image,recipe:pair)
        func pixel(_ x:Int) -> Float {var p=[Float](repeating:0,count:4);context.render(rendered,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:20,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0]}
        try check(abs(pixel(12)-0.36)<0.015 && abs(pixel(50)-0.09)<0.015,"Independent subject/background edits")
        let roundtrip=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(pair))
        try check(roundtrip==pair && roundtrip.masks[1].title=="Background","Pair persistence")
        var full=pair;full.masks.append(LocalMask(kind:.radial))
        do {_ = try full.addSubjectBackground(shared);throw StudioError.render} catch let e as NSError {try check(e.domain=="AutomaticSelection","Pair capacity")}
        #if !targetEnvironment(simulator)
        let sample=Bundle.main.url(forResource:"Sample",withExtension:"jpg")!,input=try await AutomaticSelectionEngine.input(url:sample,video:nil,recipe:Recipe())
        let before=AutomaticSelectionEngine.analysisCount
        let detected=try await AutomaticSelectionEngine.analyze(input,kind:.subject,recipe:Recipe(),videoStart:nil)
        var real=Recipe();_ = try real.addSubjectBackground(detected)
        try check(AutomaticSelectionEngine.analysisCount==before+1 && real.masks[0].automatic?.id==real.masks[1].automatic?.id,"Pair repeated inference")
        #endif
        return ["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","poolOrderRestorePruning":true,"selectiveSyncSourceIsolation":true,"recoverableSyncNoOp":true,"independentRegions":true,"sharedMatte":true,"capacityAndPersistence":true,"thermal":ProcessInfo.processInfo.thermalState.rawValue]
    }
    @MainActor static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("pool-verification.json")
        try? FileManager.default.removeItem(at:url)
        do {let result=try await Task.detached {try await run()}.value;try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
    @MainActor static func demo(_ library:StudioLibrary) async -> EditingPool? {
        guard let url=Bundle.main.url(forResource:"Sample",withExtension:"jpg") else {return nil}
        var projects=[Project]()
        for n in 1...3 {
            var project=library.projects.first(where:{$0.name=="Pool sample \(n)"})
            if project==nil {project=await library.add(url)}
            guard var p=project else {return nil};p.name="Pool sample \(n)";p.recipe=Recipe()
            if n==1,ProcessInfo.processInfo.arguments.contains("--paired-fixture"),let stored=try? matte(recipe:p.recipe) {_ = try? p.recipe.addSubjectBackground(stored)}
            guard await library.save(p) else {return nil};projects.append(p)
        }
        return EditingPool(projects:projects)
    }
}
#endif
