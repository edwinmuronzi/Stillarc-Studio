#if DEBUG
import Foundation
import CoreImage

enum ExportEstimateVerification {
    static func run() async throws ->[String:Any] {
        func check(_ b:Bool,_ s:String) throws {if !b {throw NSError(domain:"EstimateQA",code:1,userInfo:[NSLocalizedDescriptionKey:s])}}
        func photo(_ w:Int=6000,_ h:Int=4000)->Project {Project(id:UUID(),name:"QA",sourceName:"source.jpg",created:Date(),modified:Date(),recipe:Recipe(),width:w,height:h,isRAW:false)}
        func estimate(_ p:Project,_ f:ExportFormat = .jpeg,_ d:DeliverySettings = DeliverySettings(),_ policy:ExportPrivacy=ExportPrivacy()) throws ->ExportSizeEstimate {guard let e=ExportSizeEstimate.make(project:p,format:f,privacy:policy,delivery:d) else {throw StudioError.render};return e}
        let p=photo(),original=try estimate(p),png=try estimate(p,.png),heif=try estimate(p,.hdrHEIF)
        try check(png.upper>original.upper && original.upper>heif.upper,"Photo formats not distinguished")
        let smaller=DeliverySettings(size:.small,quality:.maximum),compact=DeliverySettings(size:.original,quality:.compact)
        try check(try estimate(p,.jpeg,smaller).upper<original.upper && estimate(p,.jpeg,compact).upper<original.upper,"Resize/quality")
        try check(try estimate(p,.png,compact)==png,"Lossless PNG changed with quality")
        var crop=p;crop.recipe.crop = .square
        try check(try estimate(crop).upper<original.upper,"Crop not reflected")
        var rotation=p;rotation.recipe.rotation=1
        try check(try estimate(rotation)==original,"Rotation alone changed pixel budget")
        var alpha=p;var layer=LocalMask(kind:.radial);layer.cutout=true;alpha.recipe.masks=[layer]
        try check(try estimate(alpha)==png,"Transparent cutout not forced to PNG")
        let total=ExportSizeEstimate.total(projects:[p,p],format:.jpeg,privacy:ExportPrivacy(),delivery:DeliverySettings())!
        try check(abs(total.upper-original.upper*2)<0.1,"Pool sum")
        var video=p;video.video=VideoDescriptor(width:1920,height:1080,duration:60,frameRate:29.97,transform:[1,0,0,1,0,0],detectedLog:nil,audioDataRate:1_536_000,audioChannels:[2]);video.width=1920;video.height=1080
        var hevc=DeliverySettings(),h264=DeliverySettings(),proRes=DeliverySettings();h264.codec = .h264;proRes.codec = .proRes422
        let e=try estimate(video,.jpeg,hevc),h=try estimate(video,.jpeg,h264),pro=try estimate(video,.jpeg,proRes)
        try check(pro.lower>h.upper && h.upper>e.upper,"Video codec size order")
        var mute=ExportPrivacy();mute.audio=false
        let muted=try estimate(video,.jpeg,hevc,mute)
        try check(muted.upper<e.upper,"Sound toggle")
        let expectedProRes=147_000_000.0*60/8
        let mutedPro=try estimate(video,.jpeg,proRes,mute)
        try check(abs(mutedPro.upper-(expectedProRes*1.2+65_536))<1,"Published ProRes rate")
        var trim=video;trim.recipe.video.start=10;trim.recipe.video.end=40
        try check(try estimate(trim).upper<e.upper*0.51,"Trim duration")
        var fast=video;fast.video?.frameRate=59.94
        try check(try estimate(fast,.jpeg,proRes).upper>pro.upper*1.9,"ProRes frame cadence")
        proRes.quality = .compact
        try check(try estimate(video,.jpeg,proRes)==pro,"ProRes fixed compression")
        var legacy=video;legacy.video?.audioChannels=nil;legacy.video?.audioDataRate=nil
        try check(try estimate(legacy).upper.isFinite,"Old video missing audio metadata")
        var silent=video;silent.video?.audioChannels=[];silent.video?.audioDataRate=0
        try check(try estimate(silent)==estimate(silent,.jpeg,hevc,mute),"Silent source")
        var invalid=p;invalid.width=0
        try check(ExportSizeEstimate.make(project:invalid,format:.jpeg,privacy:ExportPrivacy(),delivery:hevc)==nil && ExportSizeEstimate.total(projects:[p,invalid],format:.jpeg,privacy:ExportPrivacy(),delivery:hevc)==nil,"Unknown items silently omitted")
        for quality in DeliveryQuality.allCases {
            hevc.quality=quality
            for rate in [24.0,29.97,60,120] {
                let old=max(Int(8_000_000*quality.video),min(80_000_000,Int(1920.0*1080*max(24,rate)*0.14*quality.video)))
                try check(hevc.targetVideoBitRate(size:CGSize(width:1920,height:1080),frameRate:rate)==old,"Changed existing encoder quality")
            }
        }
        let jobs=[QueueJob(projects:[p],format:.jpeg,privacy:ExportPrivacy(),delivery:DeliverySettings()),QueueJob(projects:[video],format:.jpeg,privacy:ExportPrivacy(),delivery:h264)]
        let queued=ExportSizeEstimate.total(jobs:jobs)!
        try check(abs(queued.upper-original.upper-h.upper)<0.1,"Queue estimate settings")
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("Estimate-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let a=root.appendingPathComponent("a"),b=root.appendingPathComponent("b")
        try Data(repeating:0,count:1234).write(to:a);try Data(repeating:0,count:4321).write(to:b)
        try check(try ExportSizeEstimate.measured([a,b])==5555 && ExportSizeEstimate.measured([])==0,"Actual byte sums")
        do {_ = try ExportSizeEstimate.measured([root.appendingPathComponent("missing")]);throw NSError(domain:"EstimateQA",code:2)} catch let error as NSError {try check(error.domain != "EstimateQA","Missing actual file ignored")}
        let began=Date()
        var checksum=0.0
        for i in 0..<5000 {var d=DeliverySettings();d.codec=i%2==0 ? .h264:.hevc;var item=video;item.recipe.video.end=Double(i%58+1);if let estimate=ExportSizeEstimate.make(project:item,format:.jpeg,privacy:ExportPrivacy(),delivery:d) {checksum+=estimate.upper}}
        try check(checksum>0,"Estimate workload was not consumed")
        let elapsed=Date().timeIntervalSince(began)
        return ["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","formatsCropQualityTrimAudio":true,"legacyAudioFallback":true,"transparentPNG":true,"poolQueueTotals":true,"exactBytes":true,"encoderBudgetUnchanged":true,"arithmeticEstimates":5000,"estimateSeconds":elapsed,"estimateChecksum":checksum,"thermal":ProcessInfo.processInfo.thermalState.rawValue]
    }
    @MainActor static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("export-estimate-verification.json")
        do {let r=try await Task.detached(priority:.utility){try await run()}.value;try JSONSerialization.data(withJSONObject:r,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
