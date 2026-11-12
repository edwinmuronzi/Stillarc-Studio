import AVFoundation
import CoreImage
import UniformTypeIdentifiers

struct VideoDescriptor: Codable, Equatable, Sendable {
    var width:Int; var height:Int; var duration:Double; var frameRate:Double
    var transform:[Double]
    var detectedLog:CameraLogProfile?
    var hdrTransfer:String? = nil
    var affine:CGAffineTransform { guard transform.count == 6,transform.allSatisfy(\.isFinite) else { return .identity }; return CGAffineTransform(a:transform[0],b:transform[1],c:transform[2],d:transform[3],tx:transform[4],ty:transform[5]) }
}
enum VideoEngine {
    static func isMovie(_ url:URL) -> Bool { UTType(filenameExtension:url.pathExtension)?.conforms(to:.movie) == true || ["mov","mp4","m4v"].contains(url.pathExtension.lowercased()) }
    static func describe(_ url:URL) async throws -> VideoDescriptor {
        let asset = AVURLAsset(url:url)
        guard try await asset.load(.isPlayable), !(try await asset.load(.hasProtectedContent)), let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.unreadable }
        let size = try await track.load(.naturalSize), transform = try await track.load(.preferredTransform)
        let bounds = CGRect(origin:.zero,size:size).applying(transform)
        let duration = try await asset.load(.duration).seconds, rate = Double(try await track.load(.nominalFrameRate))
        guard max(abs(bounds.width),abs(bounds.height)) <= 4096 else { throw StudioError.unsupportedVideoSize }
        guard duration.isFinite, duration > 0, bounds.width.isFinite,bounds.height.isFinite,abs(bounds.width) >= 2, abs(bounds.height) >= 2 else { throw StudioError.unreadable }
        var log:CameraLogProfile?
        var hdrTransfer:String?
        if let format = try await track.load(.formatDescriptions).first {
            let extensions = CMFormatDescriptionGetExtensions(format) as? [String:Any] ?? [:]
            let logTag = String(describing:extensions["LogTransferFunction"] ?? "").lowercased().filter { $0.isLetter || $0.isNumber }
            if logTag.contains("applelog2") || (logTag.contains("applewidegamut") && logTag.contains("applelog")) { log = .appleLog2 }
            else if logTag.contains("applelog") { log = .appleLog }
            let transfer = String(describing:extensions[kCMFormatDescriptionExtension_TransferFunction as String] ?? "").lowercased()
            if log == nil {
                if transfer.contains("2084") { hdrTransfer = "PQ" }
                else if transfer.contains("hlg") || transfer.contains("2100") { hdrTransfer = "HLG" }
            }
        }
        return VideoDescriptor(width:Int(abs(bounds.width).rounded()),height:Int(abs(bounds.height).rounded()),duration:duration,frameRate:rate,transform:[transform.a,transform.b,transform.c,transform.d,transform.tx,transform.ty].map(Double.init),detectedLog:log,hdrTransfer:hdrTransfer)
    }
    static var pixelAttributes:[String:Any] {
        #if targetEnvironment(simulator)
        [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
        #else
        [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,kCVPixelBufferIOSurfacePropertiesKey as String:[:],AVVideoAllowWideColorKey:true]
        #endif
    }
    static func images(_ buffer:CVPixelBuffer,descriptor:VideoDescriptor,maxDimension:Double? = nil) -> (managed:CIImage,signal:CIImage) {
        func orient(_ image:CIImage) -> CIImage {
            var image = image.transformed(by:descriptor.affine)
            image = image.transformed(by:.init(translationX:-image.extent.minX,y:-image.extent.minY))
            if let maxDimension { let scale = min(1,maxDimension/max(image.extent.width,image.extent.height)); image = image.transformed(by:.init(scaleX:scale,y:scale)) }
            return image
        }
        let raw = CIImage(cvPixelBuffer:buffer,options:[.colorSpace:NSNull()])
        let managed = descriptor.detectedLog == nil ? CIImage(cvPixelBuffer:buffer) : raw.applyingFilter("CISRGBToneCurveToLinear")
        return (orient(managed),orient(raw))
    }
    static func poster(_ url:URL,descriptor:VideoDescriptor,maxDimension:Double = 1600) async throws -> PreparedPhoto {
        try ColorPipeline.prepare();try LogConversion.prepare();try HDRPipeline.prepare();try MaskEngine.prepare()
        let asset = AVURLAsset(url:url)
        guard let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.unreadable }
        let reader = try AVAssetReader(asset:asset)
        let output = AVAssetReaderTrackOutput(track:track,outputSettings:pixelAttributes)
        guard reader.canAdd(output) else { throw StudioError.unreadable }; reader.add(output)
        guard reader.startReading(), let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample) else { throw StudioError.unreadable }
        defer { reader.cancelReading() }
        let pair = images(buffer,descriptor:descriptor,maxDimension:maxDimension), context = ImageEngine.context()
        guard let managed = context.createCGImage(pair.managed,from:pair.managed.extent,format:.RGBAh,colorSpace:ImageEngine.working),
              let signal = context.createCGImage(pair.signal,from:pair.signal.extent,format:.RGBAh,colorSpace:ImageEngine.working) else { throw StudioError.render }
        return PreparedPhoto(image:CIImage(cgImage:managed),width:descriptor.width,height:descriptor.height,isRAW:false,signalImage:CIImage(cgImage:signal,options:[.colorSpace:NSNull()]))
    }

    static func export(source:URL,descriptor:VideoDescriptor,recipe:Recipe,tenBit:Bool = true,progress:@escaping @Sendable (Double) async -> Void,cooling:@escaping @Sendable (Bool) async -> Void = { _ in }) async throws -> ExportResult {
        try Task.checkCancellation()
        try ColorPipeline.prepare(); try LogConversion.prepare();try HDRPipeline.prepare();try MaskEngine.prepare()
        try MaskMotion.validateExport(recipe,duration:descriptor.duration)
        let asset = AVURLAsset(url:source)
        guard let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.unreadable }
        let reader = try AVAssetReader(asset:asset)
        let video = AVAssetReaderTrackOutput(track:track,outputSettings:pixelAttributes); video.alwaysCopiesSampleData = false
        let selection = recipe.video.range(duration:descriptor.duration)
        let trimmed = recipe.video.isTrimmed(duration:descriptor.duration)
        let trimStart = CMTime(seconds:selection.lowerBound,preferredTimescale:60000)
        let trimEnd = CMTime(seconds:selection.upperBound,preferredTimescale:60000)
        if trimmed { reader.timeRange = CMTimeRange(start:trimStart,end:trimEnd) }
        let hdr = recipe.video.hdr
        let tenBit = tenBit || hdr
        guard reader.canAdd(video) else { throw StudioError.render }; reader.add(video)
        let framed = PhotoFraming.window(in:PhotoFraming.orientedSize(CGSize(width:descriptor.width,height:descriptor.height),recipe:recipe),recipe:recipe)
        let width = max(2,Int(framed.width)/2*2),height = max(2,Int(framed.height)/2*2)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Stillarc-Video-\(UUID().uuidString.prefix(8)).mov")
        let writer = try AVAssetWriter(outputURL:url,fileType:.mov)
        var completed = false
        defer { if !completed { reader.cancelReading(); writer.cancelWriting(); try? FileManager.default.removeItem(at:url) } }
        let bitrate = max(8_000_000,min(80_000_000,Int(Double(width*height)*max(24,descriptor.frameRate)*0.14)))
        let primaries = hdr ? AVVideoColorPrimaries_ITU_R_2020 : AVVideoColorPrimaries_ITU_R_709_2
        let transfer = hdr ? AVVideoTransferFunction_ITU_R_2100_HLG : kCVImageBufferTransferFunction_sRGB as String
        let matrix = hdr ? AVVideoYCbCrMatrix_ITU_R_2020 : AVVideoYCbCrMatrix_ITU_R_709_2
        let input = AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.hevc,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoColorPropertiesKey:[AVVideoColorPrimariesKey:primaries,AVVideoTransferFunctionKey:transfer,AVVideoYCbCrMatrixKey:matrix],AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:bitrate,AVVideoExpectedSourceFrameRateKey:max(1,descriptor.frameRate),AVVideoProfileLevelKey:tenBit ? "HEVC_Main10_AutoLevel" : "HEVC_Main_AutoLevel"]])
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw StudioError.render }; writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:tenBit ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        var audio:[(AVAssetReaderTrackOutput,AVAssetWriterInput)] = []
        for audioTrack in try await asset.loadTracks(withMediaType:.audio) {
            let output = AVAssetReaderTrackOutput(track:audioTrack,outputSettings:nil); output.alwaysCopiesSampleData = false
            let hint = try await audioTrack.load(.formatDescriptions).first
            let input = AVAssetWriterInput(mediaType:.audio,outputSettings:nil,sourceFormatHint:hint)
            guard reader.canAdd(output),writer.canAdd(input) else { throw StudioError.unsupportedVideoAudio }
            reader.add(output);writer.add(input); audio.append((output,input))
        }
        let brushes = try BrushMaskRasterizer.prepareExport(layers:recipe.masks,extent:framed)
        guard writer.startWriting(),reader.startReading() else { throw StudioError.render }
        writer.startSession(atSourceTime:trimmed ? trimStart : .zero)
        let context = ImageEngine.context(), outputSpace = hdr ? HDRPipeline.hlg : ImageEngine.output
        try await withThrowingTaskGroup(of:Void.self) { group in
            group.addTask {
                var lastProgress = -1.0, frames = 0
                while let sample = video.copyNextSampleBuffer() {
                    let presentation = CMSampleBufferGetPresentationTimeStamp(sample)
                    if trimmed && (presentation < trimStart || presentation >= trimEnd) { continue }
                    try Task.checkCancellation()
                    var waiting = false
                    while ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                        if !waiting {
                            #if DEBUG
                            if ProcessInfo.processInfo.arguments.contains("--verify-video-suite") { VerificationProgress.record("Export waiting for thermal recovery") }
                            #endif
                            await cooling(true);waiting = true
                        }
                        try Task.checkCancellation();try await Task.sleep(for:.milliseconds(250))
                    }
                    if waiting { await cooling(false) }
                    if ProcessInfo.processInfo.thermalState == .fair { try await Task.sleep(for:.milliseconds(12)) }
                    while !input.isReadyForMoreMediaData { try Task.checkCancellation(); guard writer.status == .writing else { throw StudioError.render }; try await Task.sleep(for:.milliseconds(2)) }
                    try autoreleasepool {
                        guard let sourceBuffer = CMSampleBufferGetImageBuffer(sample),let pool = adaptor.pixelBufferPool else { throw StudioError.render }
                        var destination:CVPixelBuffer?
                        guard CVPixelBufferPoolCreatePixelBuffer(nil,pool,&destination) == kCVReturnSuccess,let destination else { throw StudioError.render }
                        CVBufferSetAttachment(destination,kCVImageBufferColorPrimariesKey,hdr ? kCVImageBufferColorPrimaries_ITU_R_2020 : kCVImageBufferColorPrimaries_ITU_R_709_2,.shouldPropagate)
                        CVBufferSetAttachment(destination,kCVImageBufferTransferFunctionKey,hdr ? kCVImageBufferTransferFunction_ITU_R_2100_HLG : kCVImageBufferTransferFunction_sRGB,.shouldPropagate)
                        CVBufferSetAttachment(destination,kCVImageBufferYCbCrMatrixKey,hdr ? kCVImageBufferYCbCrMatrix_ITU_R_2020 : kCVImageBufferYCbCrMatrix_ITU_R_709_2,.shouldPropagate)
                        let pair = images(sourceBuffer,descriptor:descriptor)
                        let image = MaskMotion.$frame.withValue(.init(time:presentation.seconds,framing:MaskMotion.signature(recipe))) { BrushMaskRasterizer.$preparedExport.withValue(brushes) { HDRPipeline.grade(recipe.input.profile == .standard ? pair.managed : pair.signal,recipe:recipe,hdr:hdr) } }
                        let normalized = image.transformed(by:.init(translationX:-image.extent.minX,y:-image.extent.minY))
                        context.render(normalized,to:destination,bounds:CGRect(x:0,y:0,width:width,height:height),colorSpace:outputSpace)
                        let time = CMSampleBufferGetPresentationTimeStamp(sample)
                        guard time.isNumeric,adaptor.append(destination,withPresentationTime:time) else { throw StudioError.render }
                        frames += 1
                    }
                    let p = min(0.99,max(0,(presentation.seconds-selection.lowerBound)/(selection.upperBound-selection.lowerBound)))
                    if p-lastProgress >= 0.01 { await progress(p);lastProgress = p }
                }
                guard frames > 0 else { throw StudioError.render };input.markAsFinished()
            }
            for (output,input) in audio {
                group.addTask {
                    while let sample = output.copyNextSampleBuffer() {
                        try Task.checkCancellation()
                        while !input.isReadyForMoreMediaData { try Task.checkCancellation(); guard writer.status == .writing else { throw StudioError.render };try await Task.sleep(for:.milliseconds(2)) }
                        guard input.append(sample) else { throw StudioError.render }
                    }
                    input.markAsFinished()
                }
            }
            while let _ = try await group.next() {}
        }
        guard reader.status == .completed else { throw StudioError.render }
        if trimmed { writer.endSession(atSourceTime:trimEnd) }
        await writer.finishWriting()
        try Task.checkCancellation()
        guard writer.status == .completed else { throw StudioError.render }
        completed = true;await progress(1)
        return ExportResult(url:url,width:width,height:height)
    }
}
