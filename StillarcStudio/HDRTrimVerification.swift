#if DEBUG
import AVFoundation
import CoreImage

/// Isolated generated clips; never reads or writes the user's Photos library.
enum HDRTrimVerification {
    static func run() async throws -> [String:Any] {
        func require(_ value:Bool,_ message:String) throws { if !value { throw NSError(domain:"HDRTrimVerification",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        try HDRPipeline.prepare()
        let context = ImageEngine.context()
        func pixel(_ image:CIImage) -> [Float] {
            let average = image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:image.extent)])
            var p = [Float](repeating:0,count:4);context.render(average,toBitmap:&p,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p
        }
        for value in [0.0,0.18,1,4,8] {
            let image = CIImage(color:CIColor(red:value,green:value,blue:value,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:0,width:16,height:16))
            let p = pixel(HDRPipeline.grade(image,recipe:Recipe(),hdr:true))
            try require(abs(Double(p[0])-value)<0.002,"Neutral HDR headroom changed")
        }
        let url = try await VideoFixtures.make(profile:.standard,frames:60,audioTracks:2)
        defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
        let descriptor = try await VideoEngine.describe(url)
        var recipe = Recipe();recipe.video.start = 0.2;recipe.video.end = 1.3
        let exported = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:recipe,tenBit:false,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:exported.url) }
        let asset = AVURLAsset(url:exported.url),outputDescriptor = try await VideoEngine.describe(exported.url)
        try require(abs(outputDescriptor.duration-1.1)<0.04,"Trim duration or audio tail incorrect: \(outputDescriptor.duration)")
        let track = try await asset.loadTracks(withMediaType:.video).first!
        let reader = try AVAssetReader(asset:asset),output = AVAssetReaderTrackOutput(track:track,outputSettings:nil);reader.add(output);reader.startReading()
        var times = [Double]()
        while let sample = output.copyNextSampleBuffer() { if CMSampleBufferGetTotalSampleSize(sample)>0 { times.append(CMSampleBufferGetPresentationTimeStamp(sample).seconds) } }
        times.sort()
        try require(reader.status == .completed && times.count == 33 && abs(times.first ?? 99)<0.002 && (times.last ?? 99)<1.1,"Trim frame count or zero-based timestamps incorrect: \(times.count), \(times.first ?? -1), \(times.last ?? -1)")
        let audio = try await asset.loadTracks(withMediaType:.audio)
        try require(audio.count == 2,"Trim lost an audio track")
        for track in audio {
            let range = try await track.load(.timeRange)
            try require(abs(range.start.seconds)<0.03 && abs(range.duration.seconds-1.1)<0.05,"Trimmed audio is out of sync")
        }
        let persisted = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe))
        try require(persisted.video == recipe.video && recipe.colorPreset.video == VideoEdit(),"Trim leaked into a preset or did not persist")
        let old = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8));try require(old.video == VideoEdit(),"Old trim defaults changed")
        #if !targetEnvironment(simulator)
        let log = try await VideoFixtures.make(profile:.appleLog2,frames:18,linear:[4,4,4])
        defer { try? FileManager.default.removeItem(at:log.deletingLastPathComponent()) }
        let logDescriptor = try await VideoEngine.describe(log)
        var hdr = Recipe();hdr.input.profile = .appleLog2;hdr.video.hdr = true
        let result = try await VideoEngine.export(source:log,descriptor:logDescriptor,recipe:hdr,tenBit:false,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:result.url) }
        let converted = try await VideoEngine.describe(result.url)
        try require(converted.hdrTransfer == "HLG" && converted.detectedLog == nil,"HDR output metadata incorrect")
        let native = AVURLAsset(url:result.url),format = try await native.loadTracks(withMediaType:.video).first!.load(.formatDescriptions).first!
        let extensions = CMFormatDescriptionGetExtensions(format) as? [String:Any] ?? [:]
        try require(extensions["BitsPerComponent"] as? Int == 10,"HDR did not force 10-bit output")
        let poster = try await VideoEngine.poster(result.url,descriptor:converted,maxDimension:450)
        let values = pixel(poster.image)
        try require((0..<3).allSatisfy { abs(values[$0]-4)<0.15 },"HLG roundtrip lost highlight headroom: \(values)")
        // HLG is accepted as input and can be re-exported without a Log transform.
        var roundtrip = Recipe();roundtrip.video.hdr = true
        let second = try await VideoEngine.export(source:result.url,descriptor:converted,recipe:roundtrip,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:second.url) }
        let secondDescriptor = try await VideoEngine.describe(second.url),secondPoster = try await VideoEngine.poster(second.url,descriptor:secondDescriptor,maxDimension:450)
        try require(abs(pixel(secondPoster.image)[0]-4)<0.2,"HDR input was tone-mapped twice")
        var ranged = roundtrip;var highlight = LocalMask(kind:.luminance);highlight.selection = MaskSelection(lower:0.9,upper:1);highlight.exposure = -1;ranged.masks = [highlight]
        let rangeExport = try await VideoEngine.export(source:result.url,descriptor:converted,recipe:ranged,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:rangeExport.url) }
        let rangeInfo = try await VideoEngine.describe(rangeExport.url),rangePoster = try await VideoEngine.poster(rangeExport.url,descriptor:rangeInfo,maxDimension:450)
        try require(rangeInfo.hdrTransfer == "HLG" && abs(pixel(rangePoster.image)[0]-2)<0.2,"HDR luminance-mask export lost headroom/selection")
        // A bright red channel must not darken otherwise valid SDR midtones at encode time.
        let mixed = try await VideoFixtures.make(profile:.standard,frames:12,linear:[4,0.25,0.0625],hdr:"HLG")
        defer { try? FileManager.default.removeItem(at:mixed.deletingLastPathComponent()) }
        let mixedInfo = try await VideoEngine.describe(mixed)
        let sdr = try await VideoEngine.export(source:mixed,descriptor:mixedInfo,recipe:Recipe(),progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:sdr.url) }
        let sdrInfo = try await VideoEngine.describe(sdr.url),sdrPoster = try await VideoEngine.poster(sdr.url,descriptor:sdrInfo,maxDimension:450)
        let sdrPixels = pixel(sdrPoster.image)
        try require(sdrInfo.hdrTransfer == nil && abs(sdrPixels[0]-1)<0.04 && abs(sdrPixels[1]-0.25)<0.025 && abs(sdrPixels[2]-0.0625)<0.02,"HDR-to-SDR preview clamp mismatch: \(sdrPixels)")
        let pq = try await VideoFixtures.make(profile:.standard,frames:18,linear:[4,4,4],hdr:"PQ")
        defer { try? FileManager.default.removeItem(at:pq.deletingLastPathComponent()) }
        let pqDescriptor = try await VideoEngine.describe(pq)
        try require(pqDescriptor.hdrTransfer == "PQ","PQ input was not recognized")
        let pqResult = try await VideoEngine.export(source:pq,descriptor:pqDescriptor,recipe:roundtrip,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:pqResult.url) }
        let pqOutputDescriptor = try await VideoEngine.describe(pqResult.url),pqPoster = try await VideoEngine.poster(pqResult.url,descriptor:pqOutputDescriptor,maxDimension:450)
        try require(abs(pixel(pqPoster.image)[0]-4)<0.2,"PQ to HLG conversion lost highlight headroom")
        #endif
        return ["passed":true,"trimFrames":times.count,"audioTracks":audio.count,"trimSeconds":outputDescriptor.duration,"zeroBasedTiming":true,"headroomVectors":5,"persistence":true,"presetIsolation":true,"HDRToSDRPreviewClamp":true]
    }
}
#endif
