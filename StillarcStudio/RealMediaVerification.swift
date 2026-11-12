#if DEBUG
import Foundation
import CoreImage
import CryptoKit
import UIKit
import AVFoundation

/// Opt-in developer check of explicit fixture copies. Does not enumerate Photos or user projects.
enum RealMediaVerification {
    static func require(_ value:Bool,_ message:String) throws {
        if !value { throw NSError(domain:"RealMediaQA",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
    }
    static func samples(_ image:CIImage) -> [Float] {
        let e=image.extent,scale=64/max(e.width,e.height)
        let small=image.transformed(by:CGAffineTransform(translationX:-e.minX,y:-e.minY)).transformed(by:CGAffineTransform(scaleX:scale,y:scale))
        let bounds=CGRect(x:0,y:0,width:max(1,Int(small.extent.width)),height:max(1,Int(small.extent.height)))
        var p=[Float](repeating:0,count:Int(bounds.width*bounds.height)*4)
        ImageEngine.context().render(small,toBitmap:&p,rowBytes:Int(bounds.width)*16,bounds:bounds,format:.RGBAf,colorSpace:ImageEngine.output)
        return p
    }
    static func run(_ folder:URL) throws -> [String:Any] {
        let urls=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter { ["dng","nef","arw","cr3","raf","rw2"].contains($0.pathExtension.lowercased()) }
        try require(!urls.isEmpty,"No explicit RAW fixtures")
        var results=[[String:Any]]()
        for (index,url) in urls.enumerated() {
            let originalHash=SHA256.hash(data:try Data(contentsOf:url))
            let start=ProcessInfo.processInfo.systemUptime
            let preview=try ImageEngine.open(url,maxDimension:1600)
            let openSeconds=ProcessInfo.processInfo.systemUptime-start
            try require(preview.isRAW && max(preview.image.extent.width,preview.image.extent.height)<=1602,"RAW bounded preview")
            let neutral=samples(ImageEngine.apply(preview.image,recipe:Recipe()))
            var recipe=Recipe();recipe.exposure=0.7;recipe.contrast=0.12;recipe.saturation=0.1
            let edited=samples(ImageEngine.apply(preview.image,recipe:recipe))
            try require(neutral.count==edited.count && edited.allSatisfy(\.isFinite),"Invalid RAW preview")
            let delta=zip(neutral,edited).map { abs(Double($0-$1)) }.reduce(0,+)/Double(edited.count)
            try require(delta>0.005,"RAW adjustments not visible")
            var exports=[[String:Any]]()
            for format in [ExportFormat.jpeg,.png] {
                let exportStart=ProcessInfo.processInfo.systemUptime
                let file=try ImageEngine.export(source:url,recipe:recipe,format:format)
                defer {try? FileManager.default.removeItem(at:file.url)}
                let output=try ImageEngine.open(file.url,maxDimension:1600),pixels=samples(output.image)
                try require(file.width==preview.width && file.height==preview.height,"RAW export resolution changed")
                try require(pixels.count==edited.count && pixels.allSatisfy(\.isFinite),"Invalid RAW export")
                let difference=zip(edited,pixels).map {abs(Double($0-$1))}.reduce(0,+)/Double(pixels.count)
                try require(difference<0.04,"RAW preview/export brightness or color mismatch")
                exports.append(["format":format.rawValue,"width":file.width,"height":file.height,"seconds":ProcessInfo.processInfo.systemUptime-exportStart,"previewExportMeanError":difference])
            }
            let thermalStart=ProcessInfo.processInfo.thermalState.rawValue
            var peak=thermalStart,times=[Double]()
            for i in 0..<120 {
                let t=ProcessInfo.processInfo.systemUptime
                autoreleasepool {var r=recipe;r.exposure=Double(i%30)/30;_ = samples(ImageEngine.apply(preview.image,recipe:r))}
                times.append((ProcessInfo.processInfo.systemUptime-t)*1000);peak=max(peak,ProcessInfo.processInfo.thermalState.rawValue)
            }
            try require(SHA256.hash(data:try Data(contentsOf:url))==originalHash,"RAW source changed")
            times.sort()
            results.append(["fixture":index+1,"isRAW":preview.isRAW,"width":preview.width,"height":preview.height,"openSeconds":openSeconds,"adjustmentMeanChange":delta,"exports":exports,"renderedEdits":times.count,"smallSampleRenderP95Milliseconds":times[Int(Double(times.count-1)*0.95)],"thermalStart":thermalStart,"thermalPeak":peak,"sourcePreserved":true])
        }
        return ["passed":true,"fixtures":results,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","scope":"Explicit real RAW fixture copies; sampled render timings are not interactive display latency"]
    }
    static func hash(_ url:URL) throws -> Data {
        let handle=try FileHandle(forReadingFrom:url);defer {try? handle.close()}
        var hash=SHA256()
        while let bytes=try handle.read(upToCount:1_048_576),!bytes.isEmpty {hash.update(data:bytes)}
        return Data(hash.finalize())
    }
    static func presentationTimes(_ url:URL) async throws -> [Double] {
        let asset=AVURLAsset(url:url)
        guard let track=try await asset.loadTracks(withMediaType:.video).first else {throw StudioError.unreadable}
        let reader=try AVAssetReader(asset:asset),output=AVAssetReaderTrackOutput(track:track,outputSettings:VideoEngine.pixelAttributes)
        reader.add(output);try require(reader.startReading(),"Read source timing")
        var times=[Double]()
        while let sample=output.copyNextSampleBuffer() {let t=CMSampleBufferGetPresentationTimeStamp(sample);if t.isNumeric && CMSampleBufferGetImageBuffer(sample) != nil {times.append(t.seconds)}}
        try require(reader.status == .completed,"Read source timing failed")
        return times.sorted()
    }
    static func record(_ stage:String) {
        let report=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("real-video-progress.json")
        let value:[String:Any] = ["stage":stage,"timestamp":Date().timeIntervalSince1970,"thermal":ProcessInfo.processInfo.thermalState.rawValue]
        try? JSONSerialization.data(withJSONObject:value,options:.prettyPrinted).write(to:report,options:.atomic)
        NSLog("RealMediaQA: %@",stage)
    }
    static func video(_ source:URL) async throws -> [String:Any] {
        record("Starting real clip")
        try HDRPipeline.prepare()
        let before=try hash(source),descriptor=try await VideoEngine.describe(source)
        let poster=try await VideoEngine.poster(source,descriptor:descriptor,maxDimension:1600)
        let sourceAsset=AVURLAsset(url:source),sourceAudio=try await sourceAsset.loadTracks(withMediaType:.audio).count
        record("Decode source timestamps")
        let sourceTimes=try await presentationTimes(source)
        var checks=[[String:Any]](),thermalPeak=ProcessInfo.processInfo.thermalState.rawValue
        for hdr in [false,true] {
            var recipe=Recipe();recipe.video.hdr=hdr;recipe.exposure=0.2;recipe.grain=0.12;recipe.halation=0.2
            let expected=MaskMotion.$frame.withValue(.init(time:0,framing:MaskMotion.signature(recipe))) {
                var image=HDRPipeline.grade(poster.image,recipe:recipe,hdr:hdr)
                // Match VideoPreview's SDR display clamp before comparing encoded output.
                if !hdr {image=image.applyingFilter("CIColorClamp",parameters:["inputMinComponents":CIVector(x:0,y:0,z:0,w:0),"inputMaxComponents":CIVector(x:1,y:1,z:1,w:1)])}
                return samples(image)
            }
            let start=ProcessInfo.processInfo.systemUptime
            record(hdr ? "HDR export" : "SDR export")
            let file=try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,progress:{p in let state=await MainActor.run { UIApplication.shared.applicationState.rawValue };NSLog("RealMediaQA export %.3f appState %d",p,state)},cooling:{active in record(active ? "Cooling" : "Resumed")})
            record(hdr ? "HDR verify" : "SDR verify")
            defer {try? FileManager.default.removeItem(at:file.url)}
            thermalPeak=max(thermalPeak,ProcessInfo.processInfo.thermalState.rawValue)
            let output=try await VideoEngine.describe(file.url),outPoster=try await VideoEngine.poster(file.url,descriptor:output,maxDimension:1600),actual=samples(outPoster.image)
            try require(actual.count==expected.count && actual.allSatisfy(\.isFinite),"Invalid real video output")
            let error=zip(expected,actual).map {abs(Double($0-$1))}.reduce(0,+)/Double(actual.count)
            // Record both modes before evaluating the measured match.
            try require(output.width==descriptor.width && output.height==descriptor.height && abs(output.duration-descriptor.duration)<0.07,"Real video size/duration changed")
            try require(hdr ? output.hdrTransfer=="HLG" : output.hdrTransfer==nil,"Output HDR tags")
            let asset=AVURLAsset(url:file.url),audio=try await asset.loadTracks(withMediaType:.audio).count
            try require(audio==sourceAudio,"Real video audio tracks changed")
            guard let track=try await asset.loadTracks(withMediaType:.video).first else {throw StudioError.unreadable}
            let reader=try AVAssetReader(asset:asset),stream=AVAssetReaderTrackOutput(track:track,outputSettings:nil);reader.add(stream);try require(reader.startReading(),"Read real export")
            var times=[Double]()
            while let sample=stream.copyNextSampleBuffer() {let t=CMSampleBufferGetPresentationTimeStamp(sample);if t.isNumeric && CMSampleBufferGetTotalSampleSize(sample)>0 {times.append(t.seconds)}}
            try require(reader.status == .completed && !times.isEmpty,"Unreadable exported samples")
            times.sort();try require(zip(times,times.dropFirst()).allSatisfy {$0<$1},"Duplicate output frame times")
            let decodedTimes=try await presentationTimes(file.url)
            let timingExact=decodedTimes.count==sourceTimes.count && zip(decodedTimes,sourceTimes).allSatisfy {abs($0-$1)<0.003}
            checks.append(["hdr":hdr,"frames":decodedTimes.count,"timingExact":timingExact,"outputTimes":decodedTimes,"audioTracks":audio,"width":output.width,"height":output.height,"duration":output.duration,"transfer":output.hdrTransfer ?? "SDR","previewExportMeanError":error,"previewMean":expected.reduce(0,+)/Float(expected.count),"outputMean":actual.reduce(0,+)/Float(actual.count),"seconds":ProcessInfo.processInfo.systemUptime-start])
        }
        try require(try hash(source)==before,"Real video original changed")
        return ["passed":checks.allSatisfy { ($0["previewExportMeanError"] as? Double ?? 1)<0.04 && ($0["timingExact"] as? Bool ?? false) },"sourceTransfer":descriptor.hdrTransfer ?? "SDR","sourceFPS":descriptor.frameRate,"sourcePreserved":true,"thermalPeakAtExportBoundaries":thermalPeak,"sourceFrames":sourceTimes.count,"sourceTimes":sourceTimes,"exports":checks,"scope":"Supplied real camera clip, full resolution SDR and HLG exports; sampled preview comparison, not an independent HDR display calibration"]
    }
    @MainActor static func writeVideoReport() async {
        let documents=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let source=documents.appendingPathComponent("RealMediaQA/source.mov"),report=documents.appendingPathComponent("real-video-verification.json")
        try? FileManager.default.removeItem(at:report)
        record("Started")
        let observer=NotificationCenter.default.addObserver(forName:UIApplication.didEnterBackgroundNotification,object:nil,queue:.main) {_ in record("Backgrounded")}
        let activeObserver=NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main) {_ in record("Active")}
        defer {NotificationCenter.default.removeObserver(observer);NotificationCenter.default.removeObserver(activeObserver)}
        do {
            let value=try await Task.detached(priority:.userInitiated) {try await video(source)}.value
            try JSONSerialization.data(withJSONObject:value,options:.prettyPrinted).write(to:report,options:.atomic)
            record("Finished")
        } catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:report,options:.atomic);record("Failed")}
    }
    @MainActor static func writeReport() async {
        let documents=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let folder=documents.appendingPathComponent("RealMediaQA")
        let report=documents.appendingPathComponent("real-media-verification.json")
        do {
            let value=try await Task.detached(priority:.userInitiated) {try run(folder)}.value
            try JSONSerialization.data(withJSONObject:value,options:.prettyPrinted).write(to:report,options:.atomic)
        } catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:report,options:.atomic)}
    }
}
#endif
