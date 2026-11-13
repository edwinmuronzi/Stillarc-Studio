#if DEBUG
import Foundation
import CoreImage

enum LookLibraryVerification {
    static func run() async throws ->[String:Any] {
        func check(_ ok:Bool,_ text:String) throws {if !ok {throw LookLibraryArchive.fail("Look library QA: "+text)}}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("LookLibraryQA-\(UUID())"),vault=ProjectVault(root:folder)
        defer {try? FileManager.default.removeItem(at:folder)}
        let library=await StudioLibrary(vault:vault)
        var recipe=Recipe();recipe.exposure=0.3;recipe.look = .daylight;recipe.lut=try LUTVerification.example(dimension:65)
        try check(await library.saveLook(name:"Amber",recipe:recipe),"Initial LUT save")
        try check(await library.saveLook(name:"Blue",recipe:Recipe()),"Second save")
        let initial=await library.looks,id=initial[0].id,original=try Data(contentsOf:folder.appendingPathComponent("looks.json"))
        let start=Date(),thermal=ProcessInfo.processInfo.thermalState.rawValue
        for i in 0..<30 {try check(await library.updateLookOrganization(id,favorite:i%2==0,collection:"Portraits",setCollection:true),"Metadata edit")}
        try check(await library.updateLookOrganization(id,favorite:true),"Favourite")
        try check(await library.moveLook(id,by:1),"Manual order")
        try check(try Data(contentsOf:folder.appendingPathComponent("looks.json"))==original,"Metadata rewrote embedded LUT library")
        let loaded=try await vault.load().1
        try check(loaded.last?.id==id && loaded.last?.organization?.favorite==true && loaded.last?.organization?.collection=="Portraits","Metadata/order reopen")
        try check(LookQuery.filtered(loaded,text:"portr",favorites:true,collection:"Portraits",sort:.name).count==1 && LookQuery.collections(loaded)==["Portraits"],"Filters and collection search")
        let legacyObject:[String:Any]=["id":UUID().uuidString,"name":"Old preset","recipe":[:]]
        let legacy=try JSONDecoder().decode(SavedLook.self,from:JSONSerialization.data(withJSONObject:legacyObject));try check(legacy.organization==nil,"Legacy preset migration")
        let packages=try LookLibraryArchive.write(loaded);defer {try? FileManager.default.removeItem(at:packages[0].deletingLastPathComponent())}
        let restored=try LookLibraryArchive.read(packages[0]);try check(restored.count==2 && restored.last?.recipe==recipe.colorPreset && restored.last?.organization==loaded.last?.organization,"Embedded LUT/favourite/collection roundtrip")
        let imported=try await library.importLookLibrary(restored);try check(imported.added==0 && imported.skipped==2,"Exact duplicate import")
        var changed=restored[0];changed.recipe.exposure=0.8
        let copied=try await library.importLookLibrary([changed]);try check(copied.added==1,"Conflicting preset must add a copy")
        let current=await library.looks;try check(current.count==3 && current[0].recipe==loaded[0].recipe && current.last?.id != changed.id,"Import overwrote existing look")
        let canceled=Task {withUnsafeCurrentTask {$0?.cancel()};return try await library.importLookLibrary([SavedLook(name:"Canceled",recipe:Recipe())])}
        do {_ = try await canceled.value;throw LookLibraryArchive.fail("Canceled import committed")} catch is CancellationError {}
        try check(await library.looks.count==3,"Canceled import changed count")
        var sixtyFive=[SavedLook]();for i in 0..<65 {sixtyFive.append(SavedLook(name:"Look \(i)",recipe:Recipe()))}
        let parts=try LookLibraryArchive.write(sixtyFive);defer {try? FileManager.default.removeItem(at:parts[0].deletingLastPathComponent())}
        try check(parts.count==2 && parts[0].lastPathComponent.contains("of-002"),"Numbered count split")
        var count=0;for p in parts {count += try LookLibraryArchive.read(p).count};try check(count==65,"Count split dropped presets")
        let large=(0..<6).map {SavedLook(name:"65 cube \($0)",recipe:recipe)}
        let largeParts=try LookLibraryArchive.write(large);defer {try? FileManager.default.removeItem(at:largeParts[0].deletingLastPathComponent())}
        try check(largeParts.count==2,"Byte-limited split")
        var largeCount=0;for p in largeParts {largeCount += try LookLibraryArchive.read(p).count};try check(largeCount==6,"Byte split lost LUTs")
        var sourceSpecific=recipe;sourceSpecific.crop = .square;sourceSpecific.input.profile = .appleLog;sourceSpecific.masks=[LocalMask(kind:.radial)]
        let privateLook=SavedLook(name:"Source exclusion",recipe:sourceSpecific),privateParts=try LookLibraryArchive.write([privateLook]);defer {try? FileManager.default.removeItem(at:privateParts[0].deletingLastPathComponent())}
        let safe=try LookLibraryArchive.read(privateParts[0])[0].recipe
        try check(safe.masks.isEmpty && safe.crop == .original && safe.input.profile == .standard,"Source edits leaked into look library")
        let canceledExport=Task {withUnsafeCurrentTask {$0?.cancel()};return try LookLibraryArchive.write(large)}
        do {_ = try await canceledExport.value;throw LookLibraryArchive.fail("Canceled export committed")} catch is CancellationError {}
        var bad=LookLibraryPackage(entries:[LookLibraryEntry(id:UUID(),preset:PresetDocument(name:"Bad",recipe:Recipe()),organization:nil)])
        bad.schema=2;do {_ = try bad.validated();throw LookLibraryArchive.fail("Future schema accepted")} catch let e as NSError {try check(e.localizedDescription != "Future schema accepted","Schema guard")}
        bad.schema=1;bad.entries.append(bad.entries[0]);do {_ = try bad.validated();throw LookLibraryArchive.fail("Duplicate ID accepted")} catch let e as NSError {try check(e.localizedDescription != "Duplicate ID accepted","Duplicate IDs guard")}
        let corrupt=folder.appendingPathComponent("broken.studiolooks"),bytes=try Data(contentsOf:packages[0]);try bytes.prefix(bytes.count/2).write(to:corrupt)
        do {_ = try LookLibraryArchive.read(corrupt);throw LookLibraryArchive.fail("Truncated file accepted")} catch let e as NSError {try check(e.localizedDescription != "Truncated file accepted","Truncation guard")}
        let image=CIImage(color:CIColor(red:0.2,green:0.3,blue:0.4,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:0,width:32,height:32))
        let a=ColorBatchVerification.pixel(ImageEngine.apply(image,recipe:recipe.colorPreset)),b=ColorBatchVerification.pixel(ImageEngine.apply(image,recipe:restored.last!.recipe))
        try check(zip(a,b).allSatisfy {abs($0-$1)<0.00001},"Portable preset changed rendered grade")
        return ["passed":true,"legacyMigration":true,"metadataDoesNotRewriteLUTs":true,"metadataOrderReopen":true,"filtersAndSearch":true,"LUTAndOrganizationRoundTrip":true,"renderGradeUnchanged":true,"duplicatesSkipped":true,"conflictsAddCopies":true,"cancellation":true,"canceledExport":true,"sourceSpecificEditsExcluded":true,"numberedParts":parts.count,"byteLimitedParts":largeParts.count,"malformedAndFutureRejected":true,"metadataEdits":31,"elapsedSeconds":Date().timeIntervalSince(start),"thermalStart":thermal,"thermalEnd":ProcessInfo.processInfo.thermalState.rawValue]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("look-library-verification.json")
        try? FileManager.default.removeItem(at:url)
        var report=await Task.detached(priority:.utility){()->[String:Any] in do {return try await run()} catch {return ["passed":false,"error":error.localizedDescription]}}.value
        report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
        if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
}
#endif
