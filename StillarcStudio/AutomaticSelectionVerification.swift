#if DEBUG
import CoreImage
import Foundation

enum AutomaticSelectionVerification {
    static func check(_ value:Bool,_ text:String) throws { if !value { throw NSError(domain:"AutomaticSelectionVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
    static func math() throws -> [String:Any] {
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:100,height:120),recipe = Recipe()
        func sample(_ image:CIImage,_ x:Int,_ y:Int) -> Float { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0] }
        let shape = CIImage(color:.white).cropped(to:CGRect(x:50,y:60,width:50,height:60)).composited(over:CIImage(color:.black).cropped(to:extent))
        try check(!AutomaticSelectionEngine.hasCoverage(CIImage(color:.black).cropped(to:extent)) && AutomaticSelectionEngine.hasCoverage(shape),"Empty-selection guard")
        let stored = try AutomaticMaskBitmap.make(shape,recipe:recipe,videoStart:nil)
        let decoded = AutomaticMaskBitmap.image(stored,extent:extent,preview:false)!
        try check(sample(decoded,75,90)>0.99 && sample(decoded,25,30)<0.001,"Stored matte orientation")
        let gray = CIImage(color:CIColor(red:0.25,green:0.25,blue:0.25,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        let soft = try AutomaticMaskBitmap.make(gray,recipe:recipe,videoStart:nil)
        try check(abs(sample(AutomaticMaskBitmap.image(soft,extent:extent,preview:false)!,50,60)-0.25)<0.003,"Soft probability/gamma round trip")
        var layer = LocalMask(kind:.sky);layer.automatic = stored;layer.refinement = AutomaticRefinement();layer.exposure = 1
        let weight = MaskEngine.weight(layer,extent:extent,framing:MaskMotion.signature(recipe))
        try check(sample(weight,75,90)>0.99 && sample(weight,25,30)<0.001,"Automatic mask coverage")
        var tracked = layer;tracked.kind = .subject
        tracked.motion = MaskMotion(framing:MaskMotion.signature(recipe),start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:1,x:-0.25,y:0)])
        let moving = MaskMotion.$frame.withValue(.init(time:1,framing:MaskMotion.signature(recipe))) { MaskEngine.weight(tracked,extent:extent,framing:MaskMotion.signature(recipe)) }
        try check(sample(moving,30,90)>0.99 && sample(moving,95,90)<0.001,"Stored subject tracking translation")
        layer.inverted = true
        try check(sample(MaskEngine.weight(layer,extent:extent,framing:"other crop"),25,30)<0.001,"Stale inverted mask affected whole image")
        layer.inverted = false;layer.refinement?.softness = 0.01
        let feather = sample(MaskEngine.weight(layer,extent:extent),49,90)
        try check(feather>0 && feather<0.8,"Automatic feather")
        layer.refinement?.softness = 0;layer.refinement?.expand = 0.01
        try check(sample(MaskEngine.weight(layer,extent:extent),49,90)>0.5,"Automatic grow")
        layer.refinement = AutomaticRefinement();var saved = Recipe();saved.masks = [layer]
        try check(try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(saved)) == saved,"Automatic persistence")
        try check(saved.colorPreset.masks.isEmpty && AdjustmentClipboard(name:"QA",recipe:saved,sections:Set(AdjustmentSection.allCases)).recipe.masks.isEmpty,"Automatic leaked into shared grade")
        var changed = saved;changed.crop = .square
        do { _ = try AutomaticMaskBitmap.prepare(changed);throw StudioError.render } catch let error as NSError { try check(error.domain == "AutomaticMask","Automatic crop invalidation") }
        let timed = AutomaticMask(id:UUID(),png:stored.png,width:stored.width,height:stored.height,framing:stored.framing,videoStart:0)
        var video = saved;video.video.start = 1;try check(!timed.matches(video),"First-frame invalidation")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AutoMaskQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("source.png"),source = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        try context.writePNGRepresentation(of:source,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:file),result = try ImageEngine.export(source:file,recipe:saved,format:.png)
        defer { try? FileManager.default.removeItem(at:result.url) }
        let opened = try ImageEngine.open(result.url).image
        try check(abs(sample(opened,75,90)-0.36)<0.01 && abs(sample(opened,25,30)-0.18)<0.01,"Automatic export coverage/guide exclusion")
        try check(try Data(contentsOf:file) == bytes,"Automatic export changed source")
        return ["passed":true,"orientation":true,"softProbability":true,"emptySelectionGuard":true,"storedSubjectTracking":true,"staleInvertSafe":true,"featherGrow":true,"persistence":true,"presetCopyIsolation":true,"cropClipStartGuards":true,"photoExport":true,"sourcePreserved":true]
    }
    static func inference() async throws -> [String:Any] {
        guard let url = Bundle.main.url(forResource:"Sample",withExtension:"jpg") else { throw StudioError.unreadable }
        let recipe = Recipe(),input = try await AutomaticSelectionEngine.input(url:url,video:nil,recipe:recipe)
        let context = ImageEngine.context()
        func sample(_ mask:AutomaticMask,_ x:Double,_ y:Double) -> Float {
            let extent = CGRect(x:0,y:0,width:Double(input.width),height:Double(input.height)),image = AutomaticMaskBitmap.image(mask,extent:extent,preview:false)!
            var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:extent.width*x,y:extent.height*y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0]
        }
        VerificationProgress.record("Automatic sky inference")
        let began = Date(),sky = try await AutomaticSelectionEngine.analyze(input,kind:.sky,recipe:recipe,videoStart:nil)
        let skyTop = sample(sky,0.5,0.8),street = sample(sky,0.7,0.1)
        try check(skyTop>0.6 && street<0.3,"Sky fixture coverage: \(skyTop), \(street)")
        var report:[String:Any] = ["passed":true,"skyTop":skyTop,"street":street,"skySeconds":Date().timeIntervalSince(began),"skyWidth":sky.width,"skyHeight":sky.height,"skyBytes":sky.png.count]
        #if !targetEnvironment(simulator)
        VerificationProgress.record("Automatic subject inference")
        let subjectStart = Date()
        let subject = try await AutomaticSelectionEngine.analyze(input,kind:.subject,recipe:recipe,videoStart:nil)
        let person = sample(subject,0.35,0.25),background = sample(subject,0.5,0.8)
        try check(person>0.5 && background<0.3,"Subject fixture coverage: \(person), \(background)")
        VerificationProgress.record("Automatic subject completed")
        VerificationProgress.record("Tapped subject inference")
        let picked=try await AutomaticSelectionEngine.analyze(input,kind:.subject,recipe:recipe,videoStart:nil,subjectMode:.picked,point:CGPoint(x:0.35,y:0.75))
        try check(sample(picked,0.35,0.25)>0.5 && sample(picked,0.5,0.8)<0.3,"Tapped subject coverage or vertical orientation")
        VerificationProgress.record("Refined people inference")
        let privateFixture=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("MaskPersonQA.png")
        if FileManager.default.fileExists(atPath:privateFixture.path) {
            // Optional user-supplied portrait reference, used locally for QA and never bundled or archived.
            let portrait=try ImageEngine.open(privateFixture,maxDimension:1536).image
            let bounds=portrait.extent,crop=CGRect(x:bounds.width*0.05,y:bounds.height*0.40,width:bounds.width*0.90,height:bounds.height*0.41)
            let personInput=context.createCGImage(portrait,from:crop)!
            let people=try await AutomaticSelectionEngine.analyze(personInput,kind:.subject,recipe:recipe,videoStart:nil,subjectMode:.people)
            let personMatte=AutomaticMaskBitmap.image(people,extent:CGRect(x:0,y:0,width:personInput.width,height:personInput.height),preview:false)!
            try check(AutomaticSelectionEngine.hasCoverage(personMatte),"Refined people coverage")
            report["refinedPeople"]=true
        } else {report["refinedPeopleRequiresPortraitFixture"]=true}
        report["tappedSubject"]=true
        report["subjectSeconds"] = Date().timeIntervalSince(subjectStart)
        report["subjectPerson"] = person;report["subjectSky"] = background;report["subjectWidth"] = subject.width;report["subjectHeight"] = subject.height
        #else
        report["subjectNativeOnly"] = true
        #endif
        let cancel = Task { try await AutomaticSelectionEngine.analyze(input,kind:.sky,recipe:recipe,videoStart:nil) };cancel.cancel()
        do { _ = try await cancel.value;throw StudioError.render } catch is CancellationError {}
        report["cancellation"] = true
        return report
    }
}
#endif
