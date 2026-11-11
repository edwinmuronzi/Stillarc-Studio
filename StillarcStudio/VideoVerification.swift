#if DEBUG
import Foundation
import AVFoundation
import CoreImage
import CryptoKit

enum VideoVerification {
    static func run() async throws -> [String:Any] {
        func require(_ value:Bool,_ text:String) throws { if !value { throw NSError(domain:"StudioVideoVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
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
                var masked = recipe;var layer = LocalMask(kind:.radial);layer.exposure = 1;layer.width = 0.2;layer.height = 0.2;masked.masks = [layer]
                let maskResult = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:masked,tenBit:false,progress:{ _ in })
                defer { try? FileManager.default.removeItem(at:maskResult.url) }
                let maskDescriptor = try await VideoEngine.describe(maskResult.url),maskPoster = try await VideoEngine.poster(maskResult.url,descriptor:maskDescriptor,maxDimension:450)
                func patch(_ image:CIImage,_ fx:Double,_ fy:Double) -> [Float] {
                    let rect = CGRect(x:image.extent.minX+image.extent.width*fx,y:image.extent.minY+image.extent.height*fy,width:2,height:2)
                    let average = image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:rect)])
                    var p = [Float](repeating:0,count:4);context.render(average,toBitmap:&p,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p
                }
                let base = patch(prepared.image,0.5,0.5),center = patch(maskPoster.image,0.5,0.5),outside = patch(maskPoster.image,0.1,0.1)
                try require((0..<3).allSatisfy { abs(center[$0]-base[$0]*2)<0.015 && abs(outside[$0]-base[$0])<0.015 },"Video mask changed outside pixels or exported the guide")

            }
            checks.append(["profile":profile.rawValue,"frames":originalTimes.count,"audioTracks":originalAudio.count,"width":result.width,"height":result.height,"metadata":true,"color":true,"originalPreserved":true,"projectRoundTrip":true,"cancellation":true])
        }
        #if !targetEnvironment(simulator)
        let largeURL = try await VideoFixtures.make(profile:.appleLog2,frames:3,audioTracks:0,width:3840,height:2160)
        defer { try? FileManager.default.removeItem(at:largeURL.deletingLastPathComponent()) }
        let largeDescriptor = try await VideoEngine.describe(largeURL)
        var crop = Recipe();crop.input.profile = .appleLog2;crop.crop = .square
        let largeResult = try await VideoEngine.export(source:largeURL,descriptor:largeDescriptor,recipe:crop,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:largeResult.url) }
        try require(largeResult.width == 2160 && largeResult.height == 2160,"4K source crop geometry changed")
        try require(try await frameTimes(largeResult.url).count == 3,"4K export dropped frames")
        #endif
        return ["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","clips":checks,"photoInput":try LogVerification.run(),"trimHDR":try await HDRTrimVerification.run()]
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
