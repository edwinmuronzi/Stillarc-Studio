#if DEBUG
import CoreImage
import Vision

enum Batch053Verification {
    static func check(_ value:Bool,_ text:String) throws {try Finish049Verification.check(value,text)}
    static func mathAndExport() async throws ->[String:Any] {
        let ctx=ImageEngine.context(),e=CGRect(x:0,y:0,width:256,height:192)
        let left=Finish049Verification.image([0.2,0.2,0.2],size:e.size),right=CIImage(color:CIColor(red:0.4,green:0.4,blue:0.4,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:128,y:0,width:128,height:192))
        let clean=right.composited(over:left),dirty=CIImage(color:CIColor(red:1,green:0,blue:0,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:188,y:92,width:8,height:8)).composited(over:clean)
        let spot=RetouchSpot(x:0.75,y:0.5,sourceX:0.25,sourceY:0.5,radius:0.08,kind:.heal)
        let healed=RetouchRendering.apply(dirty,spots:[spot]),value=Finish049Verification.sample(healed,x:192,y:96)
        try check(abs(value[0]-0.4)<0.025 && abs(value[1]-0.4)<0.025,"Ring healing failed local colour/blemish exclusion: \(value)")
        let translucent=CIImage(color:CIColor(red:0.3,green:0.2,blue:0.1,alpha:0.5,colorSpace:ImageEngine.working)!).cropped(to:e)
        let alpha=Finish049Verification.sample(RetouchRendering.apply(translucent,spots:[spot]),x:192,y:96)[3]
        try check(abs(alpha-0.5)<0.01,"Cleanup changed source transparency")
        let sampler=CleanupSource(dirty),target=CGPoint(x:0.75,y:0.5),suggested=sampler.suggestion(at:target,radius:0.04)
        try check(suggested != nil && hypot(suggested!.x-target.x,suggested!.y-target.y)>0.07,"Source suggestion overlapped distraction")
        let suite="Studio053-\(UUID())",defaults=UserDefaults(suiteName:suite)!;defer {defaults.removePersistentDomain(forName:suite)}
        let workflows=[SyncWorkflow(name:"Creative only",sections:[.color,.curves,.look,.lut])]
        try SyncWorkflows.save(workflows,defaults);try check(SyncWorkflows.load(defaults)==workflows,"Workflow persistence")
        do {try SyncWorkflows.save([SyncWorkflow(name:" ",sections:[])],defaults);throw PointSampling.failure("Invalid workflow saved")} catch let e as NSError {try check(e.domain != "PointSample","Workflow validation")}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("Batch053-\(UUID())");try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("dirty.png");try ctx.writePNGRepresentation(of:dirty,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let original=try Data(contentsOf:file);var r=Recipe();r.retouch=[spot]
        let out=try ImageEngine.export(source:file,recipe:r,format:.png);defer {try? FileManager.default.removeItem(at:out.url)}
        let opened=try ImageEngine.open(out.url,maxDimension:nil);try check(abs(Finish049Verification.sample(opened.image,x:192,y:96)[0]-0.4)<0.03,"Cleanup preview/export mismatch")
        try check(try Data(contentsOf:file)==original,"Cleanup altered original")
        let vault=ProjectVault(root:root.appendingPathComponent("vault"));var project=try await vault.importPhoto(file);project.recipe=r;project=try await vault.save(project)
        let preview=try await PoolCompareCache.shared.image(project,vault:vault),cached=try await PoolCompareCache.shared.image(project,vault:vault)
        try check(preview === cached && preview.width<=640 && preview.height<=640,"Pool compare not bounded/cached")
        let archive=try await vault.writeArchive([project.id]);defer {try? FileManager.default.removeItem(at:archive.deletingLastPathComponent())};let restored=try await vault.restoreArchive(archive)
        try check(restored[0].recipe==r,"Cleanup backup roundtrip")
        return ["passed":true,"healedCenter":value,"sourceSuggestion":true,"workflowPersistence":true,"invalidWorkflowRejected":true,"cleanupPNG":true,"transparencyPreserved":true,"comparisonCache":true,"sourcePreserved":true,"backup":true]
    }
    static func native(_ source:URL) async throws ->[String:Any] {
        let photo=try ImageEngine.open(source,maxDimension:1024),e=CGRect(x:0,y:0,width:640,height:480)
        let image=photo.image,scale=min(280/image.extent.width,400/image.extent.height)
        let subject=image.transformed(by:.init(translationX:-image.extent.minX,y:-image.extent.minY)).transformed(by:.init(scaleX:scale,y:scale))
        let y=(480-subject.extent.height)/2
        let left=subject.transformed(by:.init(translationX:20,y:y)),right=subject.transformed(by:.init(translationX:340,y:y))
        let scene=left.composited(over:right).composited(over:CIImage(color:.white)).cropped(to:e)
        let cg=ImageEngine.context().createCGImage(scene,from:e,format:.RGBA8,colorSpace:ImageEngine.output)!
        let a=CGPoint(x:(20+subject.extent.width*0.55)/640,y:0.5),b=CGPoint(x:(340+subject.extent.width*0.55)/640,y:0.5)
        let multiple=try await AutomaticSelectionEngine.analyze(cg,kind:.subject,recipe:Recipe(),videoStart:nil,subjectMode:.multiple,points:[a,b])
        let single=try await AutomaticSelectionEngine.analyze(cg,kind:.subject,recipe:Recipe(),videoStart:nil,subjectMode:.picked,point:a)
        let combined=AutomaticMaskBitmap.image(multiple,extent:e,preview:false)!,one=AutomaticMaskBitmap.image(single,extent:e,preview:false)!
        let pointA=Finish049Verification.sample(combined,x:a.x*640,y:240)[0],pointB=Finish049Verification.sample(combined,x:b.x*640,y:240)[0],singleB=Finish049Verification.sample(one,x:b.x*640,y:240)[0]
        try check(pointA>0.5 && pointB>0.5 && singleB<0.3,"Multi-subject isolation failed \(pointA),\(pointB),\(singleB)")
        return ["passed":true,"twoObjectsSelected":true,"singleExcludesOther":true,"scope":"Two instances of a public Smithsonian camera photograph, not a general detection accuracy benchmark"]
    }
    @MainActor static func writeReport() async {
        let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],url=docs.appendingPathComponent("batch-053-verification.json");try? FileManager.default.removeItem(at:url)
        do {let r=try await Task.detached(priority:.utility) {() async throws ->[String:Any] in
            var result:[String:Any]=["integration":try await mathAndExport()]
            if ProcessInfo.processInfo.arguments.contains("--verify-subject-models") {result["subjects"]=try await native(docs.appendingPathComponent("StudioObjectQA.jpg"))}
            result["passed"]=true;result["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown";result["thermal"]=ProcessInfo.processInfo.thermalState.rawValue;return result
        }.value;try JSONSerialization.data(withJSONObject:r,options:.prettyPrinted).write(to:url,options:.atomic)} catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
