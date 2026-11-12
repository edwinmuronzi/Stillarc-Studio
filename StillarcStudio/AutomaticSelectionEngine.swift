import AVFoundation
import CoreImage
import CoreML
import Vision

/// Request-only inference: models and working images live on the background worker, not in playback.
enum SubjectSelectionMode:String,CaseIterable,Identifiable {case foreground="All subjects",picked="Tap a subject",people="People · fine edges";var id:String {rawValue}}
enum AutomaticSelectionEngine {
    #if DEBUG
    private final class Counter:@unchecked Sendable { let lock = NSLock();var count = 0;func increment() { lock.lock();count += 1;lock.unlock() } }
    private static let counter = Counter()
    static var analysisCount:Int { counter.lock.lock();defer { counter.lock.unlock() };return counter.count }
    #endif
    static func error(_ text:String) -> NSError { NSError(domain:"AutomaticSelection",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
    static func input(url:URL,video:VideoDescriptor?,recipe:Recipe,prepared:PreparedPhoto? = nil) async throws -> CGImage {
        try Task.checkCancellation();try LogConversion.prepare()
        let source:CIImage
        if let video {
            let asset = AVURLAsset(url:url)
            guard let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.unreadable }
            let size = try await track.load(.naturalSize),scale = min(1,1024/max(size.width,size.height))
            let settings:[String:Any] = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:max(2,Int(size.width*scale)/2*2),kCVPixelBufferHeightKey as String:max(2,Int(size.height*scale)/2*2),kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
            let reader = try AVAssetReader(asset:asset),output = AVAssetReaderTrackOutput(track:track,outputSettings:settings)
            guard reader.canAdd(output) else { throw StudioError.unreadable };reader.add(output)
            let range = recipe.video.range(duration:video.duration)
            reader.timeRange = CMTimeRange(start:CMTime(seconds:range.lowerBound,preferredTimescale:60000),end:CMTime(seconds:range.upperBound,preferredTimescale:60000))
            guard reader.startReading() else { throw StudioError.unreadable };defer { reader.cancelReading() }
            guard let sample = output.copyNextSampleBuffer(),let buffer = CMSampleBufferGetImageBuffer(sample) else { throw StudioError.unreadable }
            let pair = VideoEngine.images(buffer,descriptor:video)
            var input = recipe.input;input.softHighlights = true
            var decoded = LogConversion.apply(input.profile == .standard ? pair.managed : pair.signal,input:input)
            if video.hdrTransfer != nil { decoded = decoded.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:-2]) }
            let framed = PhotoFraming.apply(decoded,recipe:recipe)
            guard let cg = ImageEngine.context().createCGImage(framed,from:framed.extent,format:.RGBA8,colorSpace:ImageEngine.output) else { throw StudioError.render };return cg
        } else {
            let opened:PreparedPhoto
            if let prepared,prepared.rawApplied == recipe.rawDevelopment {opened=prepared} else {opened=try ImageEngine.open(url,maxDimension:1536,raw:recipe.rawDevelopment,hdr:recipe.photoHDR == true)}
            source = PhotoFraming.apply(LogConversion.apply(recipe.input.profile == .standard ? opened.image : (opened.signalImage ?? opened.image),input:recipe.input),recipe:recipe)
        }
        try Task.checkCancellation()
        guard let cg = ImageEngine.context().createCGImage(source,from:source.extent,format:.RGBA8,colorSpace:ImageEngine.output) else { throw StudioError.render };return cg
    }
    static func hasCoverage(_ image:CIImage) -> Bool {
        let context = ImageEngine.context()
        func reduce(_ filter:String) -> Float {
            var values = [Float](repeating:0,count:4)
            let reduced = image.applyingFilter(filter,parameters:["inputExtent":CIVector(cgRect:image.extent)])
            context.render(reduced,toBitmap:&values,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
            return values[0]
        }
        return reduce("CIAreaMaximum")>0.5 && reduce("CIAreaAverage")>0.0001
    }
    // Vision's labels use image row order; the UI point is normalized from the top-left.
    static func instance(at point:CGPoint,buffer:CVPixelBuffer) throws ->Int? {
        guard point.x.isFinite,point.y.isFinite,(0...1).contains(point.x),(0...1).contains(point.y) else {throw error("Choose a point inside the photo.")}
        guard CVPixelBufferGetPixelFormatType(buffer)==kCVPixelFormatType_OneComponent8 else {throw error("This device returned an unsupported subject map. Use All subjects or People instead.")}
        CVPixelBufferLockBaseAddress(buffer,.readOnly);defer {CVPixelBufferUnlockBaseAddress(buffer,.readOnly)}
        guard let base=CVPixelBufferGetBaseAddress(buffer) else {throw StudioError.render}
        let x=min(CVPixelBufferGetWidth(buffer)-1,Int(point.x*Double(CVPixelBufferGetWidth(buffer)))),y=min(CVPixelBufferGetHeight(buffer)-1,Int(point.y*Double(CVPixelBufferGetHeight(buffer))))
        let value=Int(base.assumingMemoryBound(to:UInt8.self)[y*CVPixelBufferGetBytesPerRow(buffer)+x])
        return value==0 ? nil:value
    }
    static func analyze(_ image:CGImage,kind:LocalMaskKind,recipe:Recipe,videoStart:Double?,subjectMode:SubjectSelectionMode = .foreground,point:CGPoint? = nil) async throws -> AutomaticMask {
        try Task.checkCancellation()
        guard ProcessInfo.processInfo.thermalState.rawValue<ProcessInfo.ThermalState.serious.rawValue else { throw error("Let the phone cool before analyzing. Your existing masks are unchanged.") }
        #if DEBUG
        counter.increment()
        #endif
        let mask:CIImage
        if kind == .subject && subjectMode == .people {
            let request=VNGeneratePersonSegmentationRequest();request.qualityLevel = .accurate;request.outputPixelFormat=kCVPixelFormatType_OneComponent32Float;request.preferBackgroundProcessing=true
            let handler=VNImageRequestHandler(cgImage:image,orientation:.up)
            try await withTaskCancellationHandler(operation:{try handler.perform([request])},onCancel:{request.cancel()})
            try Task.checkCancellation()
            guard let buffer=request.results?.first?.pixelBuffer else {throw error("No clear person was found. Try All subjects or a brush mask.")}
            mask=CIImage(cvPixelBuffer:buffer,options:[.colorSpace:NSNull()])
        } else if kind == .subject {
            let request = VNGenerateForegroundInstanceMaskRequest();request.preferBackgroundProcessing = true
            let handler = VNImageRequestHandler(cgImage:image,orientation:.up)
            try await withTaskCancellationHandler(operation:{ try handler.perform([request]) },onCancel:{ request.cancel() })
            try Task.checkCancellation()
            guard let observation = request.results?.first,!observation.allInstances.isEmpty else { throw error("No clear foreground subject was found. Try a photo with a distinct subject, or use a brush mask.") }
            let instances:IndexSet
            if subjectMode == .picked {
                guard let point,let index=try instance(at:point,buffer:observation.instanceMask),observation.allInstances.contains(index) else {throw error("Tap inside the subject, away from its edge, then create the mask again. The previous selection is unchanged.")}
                instances=IndexSet(integer:index)
            } else {instances=observation.allInstances}
            let buffer = try observation.generateScaledMaskForImage(forInstances:instances,from:handler)
            mask = CIImage(cvPixelBuffer:buffer,options:[.colorSpace:NSNull()])
        } else {
            guard kind == .sky,let url = Bundle.main.url(forResource:"SkySegSmall",withExtension:"mlmodelc") else { throw error("The bundled sky model could not be opened.") }
            let config = MLModelConfiguration()
            #if targetEnvironment(simulator)
            config.computeUnits = .cpuOnly
            #else
            config.computeUnits = .cpuAndNeuralEngine
            #endif
            let model = try MLModel(contentsOf:url,configuration:config)
            var buffer:CVPixelBuffer?
            guard CVPixelBufferCreate(nil,384,384,kCVPixelFormatType_32BGRA,[kCVPixelBufferIOSurfacePropertiesKey as String:[:]] as CFDictionary,&buffer) == kCVReturnSuccess,let buffer else { throw StudioError.render }
            let source = CIImage(cgImage:image).transformed(by:.init(scaleX:384.0/Double(image.width),y:384.0/Double(image.height)))
            ImageEngine.context().render(source,to:buffer,bounds:CGRect(x:0,y:0,width:384,height:384),colorSpace:ImageEngine.output)
            let result = try await model.prediction(from:MLDictionaryFeatureProvider(dictionary:["image":MLFeatureValue(pixelBuffer:buffer)]))
            try Task.checkCancellation()
            guard let coverage = result.featureValue(for:"sky")?.imageBufferValue,CVPixelBufferGetWidth(coverage) == 384,CVPixelBufferGetHeight(coverage) == 384 else { throw StudioError.render }
            mask = CIImage(cvPixelBuffer:coverage,options:[.colorSpace:NSNull()])
        }
        try Task.checkCancellation()
        guard hasCoverage(mask) else {throw error(kind == .subject && subjectMode == .people ? "No clear person was found. Try All subjects, a closer crop or a brush. Existing masks are unchanged.":"No clear \(kind == .sky ? "sky":"foreground subject") was found. Try a different frame or use a brush mask. Existing masks are unchanged.")}
        return try AutomaticMaskBitmap.make(mask,recipe:recipe,videoStart:videoStart)
    }
}
