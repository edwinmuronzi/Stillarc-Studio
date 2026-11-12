#if DEBUG
import Foundation
import AVFoundation
import CoreImage
import CryptoKit

enum VideoVerification {
    static func run() async throws -> [String:Any] {
        func require(_ value:Bool,_ text:String) throws { if !value { throw NSError(domain:"StudioVideoVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        VerificationProgress.record("Video suite start")
        let context = ImageEngine.context()
        func mean(_ image:CIImage) -> [Float] {
            let reduced = image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:image.extent.insetBy(dx:4,dy:4))])
            var result = [Float](repeating:0,count:4);context.render(reduced,toBitmap:&result,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output);return result
        }
        func frameTimes(_ url:URL) async throws -> [Double] {
            let asset = AVURLAsset(url:url)
            let reader = try AVAssetReader(asset:asset)
            guard let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.render }
            let output = AVAssetReaderTrackOutput(track:track,outputSettings:nil);reader.add(output);guard reader.startReading() else { throw StudioError.render }
            var times = [Double]()
            while let sample = output.copyNextSampleBuffer() {
                let time = CMSampleBufferGetPresentationTimeStamp(sample)
                if time.isNumeric && CMSampleBufferGetTotalSampleSize(sample)>0 { times.append(time.seconds) }
            }
            try require(reader.status == .completed,"Could not read exported frames");return times.sorted()
        }
        func audioHashes(_ url:URL) async throws -> [String] {
            let asset = AVURLAsset(url:url)
            var hashes = [String]()
            for track in try await asset.loadTracks(withMediaType:.audio) {
                let reader = try AVAssetReader(asset:asset),output = AVAssetReaderTrackOutput(track:track,outputSettings:nil)
                reader.add(output);guard reader.startReading() else { throw StudioError.render }
                var hash = SHA256()
                while let sample = output.copyNextSampleBuffer() {
                    if let block = CMSampleBufferGetDataBuffer(sample) {
                        var data = Data(count:CMBlockBufferGetDataLength(block))
                        let status = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:$0.count,destination:$0.baseAddress!) }
                        try require(status == noErr,"Audio bytes unavailable");hash.update(data:data)
                    }
                }
                try require(reader.status == .completed,"Audio reader failed");hashes.append(hash.finalize().map { String(format:"%02x",$0) }.joined())
            }
            return hashes
        }
        var checks = [[String:Any]]()
        #if targetEnvironment(simulator)
        let profiles:[CameraLogProfile] = [.standard]
        #else
        let profiles:[CameraLogProfile] = [.standard,.appleLog,.appleLog2]
        #endif
        #if targetEnvironment(simulator)
        let tenBit = false
        #else
        let tenBit = true
        #endif
        for profile in profiles {
            VerificationProgress.record("Video profile \(profile.rawValue)")
            let url = try await VideoFixtures.make(profile:profile,portrait:profile == .appleLog,audioTracks:profile == .standard ? 2 : 1)
            defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
            let before = try Data(contentsOf:url),descriptor = try await VideoEngine.describe(url)
            try require(profile == .standard || descriptor.detectedLog == profile,"Log metadata was not recognized: \(profile.rawValue)")
            let prepared = try await VideoEngine.poster(url,descriptor:descriptor,maxDimension:450)
            try require(max(prepared.image.extent.width,prepared.image.extent.height)<=450,"Video poster exceeded bound")
            var recipe = Recipe();recipe.input = InputConversion(profile:profile,softHighlights:false)
            let expected = mean(ImageEngine.apply(prepared.source(for:recipe),recipe:recipe))
            if profile != .standard {
                let linear = profile.matrix.map { zip($0,VideoFixtures.scene).map(*).reduce(0,+) }
                let code = linear.map { v in v <= 0.0031308 ? v*12.92 : 1.055*pow(v,1/2.4)-0.055 }
                try require((0..<3).allSatisfy { abs(Double(expected[$0])-code[$0])<0.025 },"Decoded Log video differs from reference color: \(profile.rawValue), \(expected), \(code)")
            }
            let result = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:recipe,tenBit:tenBit,progress:{ _ in })
            defer { try? FileManager.default.removeItem(at:result.url) }
            let converted = try await VideoEngine.describe(result.url)
            try require(converted.detectedLog == nil,"SDR output retained a Log tag")
            try require(converted.width == descriptor.width && converted.height == descriptor.height,"Video export lost dimensions or rotation")
            let output = try await VideoEngine.poster(result.url,descriptor:converted,maxDimension:450)
            let actual = mean(output.image)
            try require((0..<3).allSatisfy { abs(actual[$0]-expected[$0])<0.025 },"Preview/export color mismatch: \(profile.rawValue) expected=\(expected) actual=\(actual)")
            let originalTimes = try await frameTimes(url),exportedTimes = try await frameTimes(result.url)
            try require(originalTimes.count == exportedTimes.count && !originalTimes.isEmpty,"Video export dropped frames")
            try require(zip(originalTimes,exportedTimes).allSatisfy { abs($0-$1)<0.002 },"Video export changed source frame timing")
            let originalAudio = try await audioHashes(url),exportedAudio = try await audioHashes(result.url)
            try require(originalAudio == exportedAudio,"Video export changed or dropped audio")
            try require(abs(converted.duration-descriptor.duration)<0.05,"Video duration/audio sync changed")
            try require(try Data(contentsOf:url) == before,"Video original was modified")
            let vaultRoot = FileManager.default.temporaryDirectory.appendingPathComponent("StudioVideoVaultQA-\(UUID())"),vault = ProjectVault(root:vaultRoot)
            defer { try? FileManager.default.removeItem(at:vaultRoot) }
            var project = try await vault.importPhoto(url);project.recipe = recipe
            try await vault.save(project);let loaded = try await vault.load()
            try require(loaded.0.first?.video == descriptor && loaded.0.first?.recipe == recipe,"Video project did not reopen with its settings")
            let task = Task { try await VideoEngine.export(source:url,descriptor:descriptor,recipe:recipe,tenBit:tenBit,progress:{ _ in }) }
            task.cancel()
            do { _ = try await task.value;throw NSError(domain:"StudioVideoVerification",code:2,userInfo:[NSLocalizedDescriptionKey:"Cancelled video export completed"]) }
            catch is CancellationError {}
            if profile == .standard {
                let alternate = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:recipe,tenBit:false,progress:{ _ in })
                defer { try? FileManager.default.removeItem(at:alternate.url) }
                let alternateDescriptor = try await VideoEngine.describe(alternate.url)
                let alternatePoster = try await VideoEngine.poster(alternate.url,descriptor:alternateDescriptor,maxDimension:450)
                let alternateMean = mean(alternatePoster.image)
                try require((0..<3).allSatisfy { abs(alternateMean[$0]-expected[$0])<0.025 },"8-bit alternate export color mismatch")
                var masked = recipe;var layer = LocalMask(kind:.brush);layer.exposure = 1
                var ink = BrushDrawing();let stroke = ink.begin(point:BrushPoint(x:0.25,y:0.2),radius:0.08,feather:0.5,erase:false)!;ink.append(BrushPoint(x:0.75,y:0.2),stroke:stroke);_ = ink.begin(point:BrushPoint(x:0.5,y:0.2),radius:0.025,feather:0.2,erase:true);layer.brush = ink;layer.exposure = 0;layer.enabled = false
                var combined = LocalMask(kind:.luminance);combined.exposure = 1;combined.selection = MaskSelection(lower:0,upper:1);combined.combination = .intersect;masked.masks = [layer,combined]
                let maskResult = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:masked,tenBit:false,progress:{ _ in })
                defer { try? FileManager.default.removeItem(at:maskResult.url) }
                let maskDescriptor = try await VideoEngine.describe(maskResult.url),maskPoster = try await VideoEngine.poster(maskResult.url,descriptor:maskDescriptor,maxDimension:450)
                func patch(_ image:CIImage,_ fx:Double,_ fy:Double) -> [Float] {
                    let rect = CGRect(x:image.extent.minX+image.extent.width*fx,y:image.extent.minY+image.extent.height*fy,width:2,height:2)
                    let average = image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:rect)])
                    var p = [Float](repeating:0,count:4);context.render(average,toBitmap:&p,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p
                }
                let base = patch(prepared.image,0.5,0.5),center = patch(maskPoster.image,0.35,0.8),outside = patch(maskPoster.image,0.5,0.3),erased = patch(maskPoster.image,0.5,0.8)
                try require((0..<3).allSatisfy { abs(center[$0]-base[$0]*2)<0.015 && abs(outside[$0]-base[$0])<0.015 && abs(erased[$0]-base[$0])<0.015 },"Video mask changed outside pixels or exported the guide")

                let automaticExtent = prepared.image.extent
                let autoShape = CIImage(color:.white).cropped(to:CGRect(x:automaticExtent.width*0.2,y:automaticExtent.height*0.65,width:automaticExtent.width*0.6,height:automaticExtent.height*0.3)).composited(over:CIImage(color:.black).cropped(to:automaticExtent))
                var automaticRecipe = recipe,automaticLayer = LocalMask(kind:.subject)
                automaticLayer.automatic = try AutomaticMaskBitmap.make(autoShape,recipe:recipe,videoStart:0);automaticLayer.exposure = 1;automaticRecipe.masks = [automaticLayer]
                let automaticOutput = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:automaticRecipe,tenBit:false,progress:{ _ in })
                defer { try? FileManager.default.removeItem(at:automaticOutput.url) }
                let automaticInfo = try await VideoEngine.describe(automaticOutput.url),automaticPoster = try await VideoEngine.poster(automaticOutput.url,descriptor:automaticInfo,maxDimension:450)
                let automaticInside = patch(automaticPoster.image,0.35,0.8),automaticOutside = patch(automaticPoster.image,0.5,0.3)
                try require((0..<3).allSatisfy { abs(automaticInside[$0]-base[$0]*2)<0.015 && abs(automaticOutside[$0]-base[$0])<0.015 },"Automatic matte video export or guide isolation")
                try require(try await frameTimes(automaticOutput.url).count == originalTimes.count,"Automatic mask dropped video frames")
                for kind in [LocalMaskKind.color,.luminance] {
                    var range = LocalMask(kind:kind);range.exposure = 1
                    range.selection = MaskSelection(hue:30,tolerance:90,lower:0,upper:1)
                    for invert in [false,true] {
                        range.inverted = invert;var test = recipe;test.masks = [range]
                        let encoded = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:test,tenBit:false,progress:{ _ in })
                        let info = try await VideoEngine.describe(encoded.url)
                        let poster = try await VideoEngine.poster(encoded.url,descriptor:info,maxDimension:450)
                        let actual = patch(poster.image,0.5,0.5),factor:Float = invert ? 1 : 2
                        try require((0..<3).allSatisfy { abs(actual[$0]-base[$0]*factor)<0.015 },"Encoded range selection/guide mismatch")
                        try require(try await frameTimes(encoded.url).count == originalTimes.count,"Range export dropped frames")
                        try? FileManager.default.removeItem(at:encoded.url)
                    }
                }

            }
            checks.append(["profile":profile.rawValue,"frames":originalTimes.count,"audioTracks":originalAudio.count,"width":result.width,"height":result.height,"metadata":true,"color":true,"originalPreserved":true,"projectRoundTrip":true,"cancellation":true])
        }
        #if !targetEnvironment(simulator)
        let largeURL = try await VideoFixtures.make(profile:.appleLog2,frames:3,audioTracks:0,width:3840,height:2160)
        defer { try? FileManager.default.removeItem(at:largeURL.deletingLastPathComponent()) }
        let largeDescriptor = try await VideoEngine.describe(largeURL)
        var crop = Recipe();crop.input.profile = .appleLog2;crop.crop = .square
        VerificationProgress.record("4K Log tracking preview")
        let trackingPoster = try await MaskTracker.seedFrame(url:largeURL,descriptor:largeDescriptor,recipe:crop)
        try require(max(trackingPoster.width,trackingPoster.height)<=640 && trackingPoster.width == trackingPoster.height,"4K Log tracking decode/framing exceeded bound")
        let largeResult = try await VideoEngine.export(source:largeURL,descriptor:largeDescriptor,recipe:crop,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:largeResult.url) }
        try require(largeResult.width == 2160 && largeResult.height == 2160,"4K source crop geometry changed")
        try require(try await frameTimes(largeResult.url).count == 3,"4K export dropped frames")
        let resized = CropEditingGeometry.resize(crop,size:CGSize(width:3840,height:2160),corner:.bottomRight,delta:CGSize(width:-300,height:-300))
        let scaledResult = try await VideoEngine.export(source:largeURL,descriptor:largeDescriptor,recipe:resized,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:scaledResult.url) }
        try require(scaledResult.width == 1860 && scaledResult.height == 1860,"Corner-resized encoded video does not match frame")
        try require(try await frameTimes(scaledResult.url).count == 3,"Corner-resized export dropped frames")
        checks.append(["cornerResized4KLog":true,"width":scaledResult.width,"height":scaledResult.height,"frames":3])
        #endif
        return ["maskTracking":try await TrackingVerification.video(),"passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","clips":checks,"photoInput":try LogVerification.run(),"boundedTrackingDecode":true,"encodedAutomaticMask":true,"encodedCombinedBrushRangeMask":true,"encodedColorLuminanceMasks":true,"trimHDR":try await HDRTrimVerification.run()]
    }
    @MainActor static func writeReport() async {
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("video-verification.json")
        do {
            let result = try await Task.detached(priority:.userInitiated) { try await run() }.value
            try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:url,options:.atomic)
        } catch {
            let result:[String:Any] = ["passed":false,"error":error.localizedDescription]
            if let data = try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
        }
    }
}
#endif
