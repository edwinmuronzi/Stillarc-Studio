#if DEBUG
import Foundation
import CoreImage

@MainActor enum ExportQueueVerification {
    static func run() async throws ->[String:Any] {
        func check(_ value:Bool,_ message:String) throws {if !value {throw ProjectArchive.fail("Queue QA: "+message)}}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("QueueQA-\(UUID())")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("source.png")
        try await Task.detached(priority:.utility){try ImageEngine.context().writePNGRepresentation(of:CIImage(color:CIColor(red:0.2,green:0.4,blue:0.6)).cropped(to:CGRect(x:0,y:0,width:320,height:240)),to:file,format:.RGBA8,colorSpace:ImageEngine.output)}.value
        let vault=ProjectVault(root:folder.appendingPathComponent("vault")),p=try await vault.importPhoto(file)
        let queue=StudioExportQueue(vault:vault,root:folder.appendingPathComponent("queue"));await queue.load()
        var snapshot=p;snapshot.recipe.exposure=0.5
        let added=await queue.enqueue([snapshot],format:.png,privacy:ExportPrivacy(),delivery:DeliverySettings(size:.small,quality:.balanced))
        try check(added && queue.pending==1 && !queue.running,"Explicit start")
        snapshot.recipe.exposure = -0.5
        _ = await queue.enqueue([snapshot],format:.jpeg,privacy:ExportPrivacy(),delivery:DeliverySettings())
        let second=queue.jobs[1].id;await queue.move(second,by:-1)
        try check(queue.jobs.first?.id==second,"Reordering")
        await queue.cancel(second);try check(queue.jobs[0].state == .cancelled,"Waiting cancellation")
        await queue.retry(second);try check(queue.jobs[0].state == .waiting,"Retry")
        queue.start();await queue.waitUntilIdle()
        try check(queue.jobs.allSatisfy {$0.state == .completed && $0.files.count==1} && !queue.running,"Sequential completion")
        let bright=queue.jobs.first {$0.format == .png}!,url=queue.urls(bright)[0]
        let image=try ImageEngine.open(url,maxDimension:320)
        try check(image.width==320 && image.height==240 && bright.projects[0].recipe.exposure==0.5 && p.recipe.exposure==0,"Queued size/source snapshot")
        let recoveryStore=ExportQueueStore(root:folder.appendingPathComponent("recovery-queue"));var unfinished=bright;unfinished.state = .running;unfinished.files=[];try await recoveryStore.save([unfinished])
        let recovered=StudioExportQueue(vault:vault,root:folder.appendingPathComponent("recovery-queue"));await recovered.load()
        try check(recovered.jobs[0].state == .waiting && !recovered.running,"Interrupted process recovery")
        let recreated=StudioExportQueue(vault:vault,root:folder.appendingPathComponent("queue"));await recreated.load()
        try check(recreated.jobs.count==2 && !recreated.running && recreated.jobs.allSatisfy {$0.state == .completed} && recreated.urls(recreated.jobs[0]).allSatisfy {FileManager.default.fileExists(atPath:$0.path)},"Retained completed files")
        let missing=try await vault.importPhoto(file);try await vault.remove(missing)
        _ = await recreated.enqueue([missing],format:.png,privacy:ExportPrivacy(),delivery:DeliverySettings())
        recreated.start();await recreated.waitUntilIdle()
        try check(recreated.jobs.last?.state == .failed && recreated.jobs.last?.failures.isEmpty == false,"Missing source failure")
        let completedID=recreated.jobs[0].id,completedURLs=recreated.urls(recreated.jobs[0]);await recreated.remove(completedID)
        try check(!recreated.jobs.contains {$0.id==completedID} && completedURLs.allSatisfy {!FileManager.default.fileExists(atPath:$0.path)},"Output removal")
        // Pause a live video job; its source and completed earlier jobs remain intact.
        let movie=try await VideoFixtures.make(profile:.standard,frames:90,audioTracks:1,width:640,height:360);defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        let v=try await vault.importPhoto(movie)
        _ = await recreated.enqueue([v],format:.jpeg,privacy:ExportPrivacy(),delivery:DeliverySettings())
        let videoID=recreated.jobs.last!.id
        recreated.start();try? await Task.sleep(for:.milliseconds(20));recreated.pause();await recreated.waitUntilIdle()
        try check(!recreated.running && recreated.jobs.first(where:{$0.id==videoID})?.state != .running,"Pause cleanup")
        let reopened=StudioExportQueue(vault:vault,root:folder.appendingPathComponent("queue"));await reopened.load()
        try check(!reopened.running,"No automatic relaunch export")
        reopened.start();await reopened.waitUntilIdle()
        let delivered=reopened.jobs.first {$0.id==videoID}!
        try check(delivered.state == .completed && delivered.files.count==1,"Resumed video delivery")
        let videoOut=try await VideoEngine.describe(reopened.urls(delivered)[0])
        try check(videoOut.width==640 && videoOut.height==360 && abs(videoOut.duration-v.video!.duration)<0.04,"Queued video timing")
        return ["passed":true,"explicitStartAndSnapshot":true,"reorderCancelRetry":true,"serialPhotoVideoExports":true,"completedFilesSurviveReload":true,"interruptedProcessRecovery":true,"missingSourceHandled":true,"pauseResumeAndNoAutoStart":true,"outputRemoval":true]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("export-queue-verification.json")
        try? FileManager.default.removeItem(at:url)
        let began=Date();var result:[String:Any]
        do {result=try await run()} catch {result=["passed":false,"error":error.localizedDescription]}
        result["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;result["thermal"]=ProcessInfo.processInfo.thermalState.rawValue;result["seconds"]=Date().timeIntervalSince(began)
        if let data=try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
}
#endif
