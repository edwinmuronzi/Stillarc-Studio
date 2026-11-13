#if DEBUG
import AVFoundation
import CoreImage
import Foundation

enum DeliveryCodecVerification {
    static func run() async throws ->[String:Any] {
        func check(_ b:Bool,_ text:String) throws {if !b {throw NSError(domain:"DeliveryCodecQA",code:1,userInfo:[NSLocalizedDescriptionKey:text])}}
        let legacy=try JSONDecoder().decode(DeliverySettings.self,from:Data("{\"size\":\"Original\",\"quality\":\"Maximum\"}".utf8))
        try check(legacy.codec == .hevc,"Legacy delivery changed codec")
        let suite="StudioCodecQA-\(UUID())",defaults=UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        let date=AVMutableMetadataItem();date.identifier = .quickTimeMetadataCreationDate;date.value="2026-11-13T12:00:00Z" as NSString;date.dataType=kCMMetadataBaseDataType_UTF8 as String
        let make=AVMutableMetadataItem();make.identifier = .quickTimeMetadataMake;make.value="Apple" as NSString;make.dataType=kCMMetadataBaseDataType_UTF8 as String
        let model=AVMutableMetadataItem();model.identifier = .quickTimeMetadataModel;model.value="Studio QA" as NSString;model.dataType=kCMMetadataBaseDataType_UTF8 as String
        let location=AVMutableMetadataItem();location.identifier = .quickTimeMetadataLocationISO6709;location.value="+48.0000+002.0000/" as NSString;location.dataType=kCMMetadataBaseDataType_UTF8 as String
        let source=try await VideoFixtures.make(profile:.appleLog2,frames:24,audioTracks:1,width:640,height:360,linear:[0.8,0.6,0.4],metadata:[date,make,model,location])
        defer {try? FileManager.default.removeItem(at:source.deletingLastPathComponent())}
        let descriptor=try await VideoEngine.describe(source)
        let context=ImageEngine.context()
        func pixel(_ image:CIImage)->[Float] {var v=[Float](repeating:0,count:4);let area=image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:image.extent.insetBy(dx:4,dy:4))]);context.render(area,toBitmap:&v,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return v}
        var recipe=Recipe();recipe.input.profile = .appleLog2;recipe.exposure=0.2;recipe.video.start=0.1;recipe.video.end=0.6;recipe.rotation=1
        recipe.rgbCurves.red.nodes=[CurveNode(x:0,y:0),CurveNode(x:0.2,y:0.22),CurveNode(x:1,y:1)]
        recipe.lut=try LUTVerification.example();recipe.lutLayers=[LUTLayer(asset:recipe.lut!,amount:0.2)]
        let poster=try await VideoEngine.poster(source,descriptor:descriptor,maxDimension:640,time:0.2)
        var results=[[String:Any]]()
        for codec in VideoDeliveryCodec.allCases where codec.available {
            for hdr in [false,true] where !(hdr && codec == .h264) {
                VerificationProgress.record("Codec \(codec.rawValue) HDR \(hdr)")
                var delivery=DeliverySettings(size:.small,quality:.balanced);delivery.codec=codec
                delivery.save(defaults);try check(DeliverySettings.load(defaults)==delivery,"Remembered codec")
                recipe.video.hdr=hdr
                let began=Date()
                let result=try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,privacy:ExportPrivacy(captureDate:true,camera:codec != .h264,location:true),delivery:delivery,progress:{_ in})
                defer {try? FileManager.default.removeItem(at:result.url)}
                let asset=AVURLAsset(url:result.url),out=try await VideoEngine.describe(result.url)
                let tracks=try await asset.loadTracks(withMediaType:.video),audio=try await asset.loadTracks(withMediaType:.audio)
                guard let track=tracks.first,let format=try await track.load(.formatDescriptions).first else {throw StudioError.unreadable}
                let expectedCodec:CMVideoCodecType = codec == .h264 ? kCMVideoCodecType_H264:codec == .hevc ? kCMVideoCodecType_HEVC:kCMVideoCodecType_AppleProRes422
                try check(CMFormatDescriptionGetMediaSubType(format)==expectedCodec,"Wrong encoded codec")
                try check(out.width==360 && out.height==640 && abs(out.duration-0.5)<0.04 && audio.count==1,"Orientation/trim/audio \(codec)")
                try check(result.url.pathExtension==codec.fileExtension && (out.hdrTransfer != nil)==hdr,"Container/HDR \(codec)")
                var metadata=[AVMetadataItem]()
                for format in try await asset.load(.availableMetadataFormats) {metadata += try await asset.loadMetadata(for:format)}
                var strings=[String]();for item in metadata {if let value=try await item.load(.stringValue) {strings.append(value)}}
                try check(strings.contains("2026-11-13T12:00:00Z") && strings.contains(where:{$0.hasPrefix("+48.0000+002.0000")}),"Requested date/location missing \(codec): \(strings)")
                if codec != .h264 {try check(strings.contains("Apple") && strings.contains("Studio QA"),"MOV camera details missing")}
                if codec == .h264,let audioTrack=audio.first,let af=try await audioTrack.load(.formatDescriptions).first {try check(CMFormatDescriptionGetMediaSubType(af)==kAudioFormatMPEG4AAC,"MP4 audio is not AAC")}
                let actual=try await VideoEngine.poster(result.url,descriptor:out,maxDimension:640,time:0.1)
                let expected=HDRPipeline.grade(poster.source(for:recipe),recipe:recipe,hdr:hdr)
                let error=zip(pixel(actual.image),pixel(expected)).map {abs($0-$1)}.max() ?? 99
                try check(error<0.045,"Codec colour mismatch \(codec) HDR \(hdr): \(error)")
                results.append(["codec":codec.rawValue,"hdr":hdr,"previewExportMaxError":error,"seconds":Date().timeIntervalSince(began),"bytes":(try result.url.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0])
            }
        }
        var fourK=[[String:Any]]()
        if VideoDeliveryCodec.proResHardware {
            let original=try await VideoFixtures.make(profile:.appleLog2,frames:12,audioTracks:1,width:3840,height:2160,linear:[1.5,1.2,0.9])
            defer {try? FileManager.default.removeItem(at:original.deletingLastPathComponent())}
            let description=try await VideoEngine.describe(original)
            var master=Recipe();master.input.profile = .appleLog2;var delivery=DeliverySettings();delivery.codec = .proRes422
            for hdr in [false,true] {
                master.video.hdr=hdr
                VerificationProgress.record("4K ProRes HDR \(hdr)")
                let out=try await VideoEngine.export(source:original,descriptor:description,recipe:master,delivery:delivery,progress:{_ in})
                defer {try? FileManager.default.removeItem(at:out.url)}
                let read=try await VideoEngine.describe(out.url),frame=try await VideoEngine.poster(out.url,descriptor:read,maxDimension:640)
                try check(read.width==3840 && read.height==2160 && abs(read.duration-0.4)<0.04 && (read.hdrTransfer != nil)==hdr,"4K ProRes dimensions/timing/HDR")
                let values=pixel(frame.image);try check(values.allSatisfy(\.isFinite) && values[0]>0.5 && (!hdr || values[0]>1),"4K ProRes image/headroom")
                fourK.append(["hdr":hdr,"width":read.width,"height":read.height,"redLinear":values[0]])
            }
        }
        var h264=DeliverySettings();h264.codec = .h264;recipe.video.hdr=true
        do {_ = try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,delivery:h264,progress:{_ in});throw NSError(domain:"DeliveryCodecQA",code:2,userInfo:[NSLocalizedDescriptionKey:"HDR silently converted to H.264"])} catch let e as NSError {try check(e.domain=="Delivery" && e.code==2,"HDR rejection")}
        recipe.video.hdr=false
        do {_ = try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,privacy:ExportPrivacy(camera:true),delivery:h264,progress:{_ in});throw NSError(domain:"DeliveryCodecQA",code:2,userInfo:[NSLocalizedDescriptionKey:"MP4 silently discarded camera details"])} catch let e as NSError {try check(e.domain=="Delivery" && e.code==4,"MP4 camera metadata guard")}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("CodecQueue-\(UUID())")
        defer {try? FileManager.default.removeItem(at:root)}
        let vault=ProjectVault(root:root.appendingPathComponent("vault"))
        var project=try await vault.importPhoto(source);project.recipe=recipe;project=try await vault.save(project)
        let store=ExportQueueStore(root:root.appendingPathComponent("queue")),job=QueueJob(projects:[project],format:.jpeg,privacy:ExportPrivacy(),delivery:h264)
        try await store.save([job]);let loaded=try await store.load();try check(loaded.first?.delivery.codec == .h264,"Queue lost codec")
        let batch=try await BatchExportEngine.run(loaded[0].projects,vault:vault,format:.jpeg,delivery:loaded[0].delivery,progress:{_,_,_ in})
        defer {try? FileManager.default.removeItem(at:batch.folder)}
        try check(batch.failures.isEmpty && batch.urls.count==1 && batch.urls[0].pathExtension=="mp4","Queued/batch codec delivery")
        var silent=ExportPrivacy();silent.audio=false
        let noAudio=try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,privacy:silent,delivery:h264,progress:{_ in})
        defer {try? FileManager.default.removeItem(at:noAudio.url)}
        let noTracks=try await AVURLAsset(url:noAudio.url).loadTracks(withMediaType:.audio);try check(noTracks.isEmpty,"Silent H.264 export")
        return ["passed":true,"exports":results,"fourKProRes":fourK,"requestedMetadata":true,"proResHardware":VideoDeliveryCodec.proResHardware,"HDRGuard":true,"queueBatchCodec":true,"legacyDefaults":true,"rememberedSettings":true,"silentExport":true,"thermal":ProcessInfo.processInfo.thermalState.rawValue]
    }
    @MainActor static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("delivery-codec-verification.json")
        let began=Date().timeIntervalSince1970
        do {var r=try await Task.detached(priority:.utility){try await run()}.value;r["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;r["started"]=began;try JSONSerialization.data(withJSONObject:r,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription,"started":began,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
