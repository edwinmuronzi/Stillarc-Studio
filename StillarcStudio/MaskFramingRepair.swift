import CoreImage
import Foundation

/// Crop changes transform the saved selection, never rerun inference while dragging.
enum MaskFramingRepair {
    static func snapshot(_ signature:String) -> Recipe? {
        let rawParts=signature.components(separatedBy:":rawLens=")
        guard rawParts.count<=2 else {return nil}
        let lens = rawParts[0].components(separatedBy:":lens=")
        guard lens.count<=2 else { return nil }
        let parts = lens[0].components(separatedBy:":cropScale=")
        guard parts.count<=2,let colon = parts[0].lastIndex(of:":"),let crop = Crop(rawValue:String(parts[0][..<colon])) else { return nil }
        let numbers = parts[0][parts[0].index(after:colon)...].split(separator:",").compactMap { Double($0) }
        guard numbers.count == 10,numbers.allSatisfy({ $0.isFinite }),numbers[0]>=0,numbers[0]<=3 else { return nil }
        var r = Recipe();r.crop = crop;r.rotation = Int(numbers[0]);r.straighten = numbers[1];r.cropX = numbers[2];r.cropY = numbers[3]
        r.geometry.width = numbers[4];r.geometry.height = numbers[5];r.geometry.flipHorizontal = numbers[6] == 1;r.geometry.flipVertical = numbers[7] == 1;r.geometry.horizontal = numbers[8];r.geometry.vertical = numbers[9]
        if parts.count == 2 { guard let scale = Double(parts[1]),scale.isFinite else { return nil };r.geometry.cropScale = scale }
        if lens.count == 2 { guard let value = Double(lens[1]),value.isFinite,abs(value)<=0.25 else { return nil };r.geometry.lensDistortion = value }
        if rawParts.count == 2 {guard let enabled=Bool(rawParts[1]) else {return nil};r.rawDevelopment=RawDevelopment();r.rawDevelopment?.lensProfile=enabled}
        return MaskMotion.signature(r) == signature ? r : nil
    }
    static func sameField(_ a:Recipe,_ b:Recipe) -> Bool {
        a.rawDevelopment?.lensProfile == b.rawDevelopment?.lensProfile && a.geometry.lensDistortion == b.geometry.lensDistortion && a.rotation == b.rotation && a.straighten == b.straighten && a.geometry.flipHorizontal == b.geometry.flipHorizontal && a.geometry.flipVertical == b.geometry.flipVertical && a.geometry.horizontal == b.geometry.horizontal && a.geometry.vertical == b.geometry.vertical
    }
    static func reframe(_ stored:AutomaticMask,to recipe:Recipe,sourceSize:CGSize) throws -> AutomaticMask? {
        guard stored.videoStart == nil || abs((stored.videoStart ?? 0)-recipe.video.start)<0.002 else { return nil }
        let anchor = stored.anchor ?? AutomaticMaskAnchor(id:stored.id,png:stored.png,width:stored.width,height:stored.height,framing:stored.framing)
        guard let old = snapshot(anchor.framing),sameField(old,recipe),sourceSize.width>0,sourceSize.height>0 else { return nil }
        let source = AutomaticMask(id:anchor.id,png:anchor.png,width:anchor.width,height:anchor.height,framing:anchor.framing,videoStart:stored.videoStart)
        guard let cg = AutomaticMaskBitmap.decode(source) else { throw StudioError.render }
        let size = PhotoFraming.orientedSize(sourceSize,recipe:recipe)
        let before = PhotoFraming.window(in:size,recipe:old),after = PhotoFraming.window(in:size,recipe:recipe)
        // A bounded canvas avoids allocating a full-resolution source-sized matte.
        let scale = min(1,1024/max(after.width,after.height))
        let target = CGRect(x:0,y:0,width:max(1,floor(after.width*scale)),height:max(1,floor(after.height*scale)))
        let sx = target.width/after.width,sy = target.height/after.height
        let selected = CIImage(cgImage:cg,options:[.colorSpace:NSNull()])
            .transformed(by:.init(scaleX:before.width/Double(cg.width)*sx,y:before.height/Double(cg.height)*sy))
            .transformed(by:.init(translationX:(before.minX-after.minX)*sx,y:(before.minY-after.minY)*sy))
            .composited(over:CIImage(color:.black).cropped(to:target)).cropped(to:target)
        var result = try AutomaticMaskBitmap.make(selected,recipe:recipe,videoStart:stored.videoStart);result.anchor = anchor;result.selectionMode=stored.selectionMode
        return result
    }
    /// Adopt repaired geometry without overwriting controls changed while the worker ran.
    static func merge(_ repaired:Recipe,snapshot:Recipe,current:Recipe) -> [LocalMask] {
        guard MaskMotion.signature(current)==MaskMotion.signature(snapshot),current.video.start==snapshot.video.start else {return current.masks}
        return current.masks.map {layer in
            guard let old=snapshot.masks.first(where:{$0.id==layer.id}),let new=repaired.masks.first(where:{$0.id==layer.id}),layer.automatic==old.automatic else {return layer}
            var copy=layer;copy.automatic=new.automatic
            if layer.motion==old.motion {copy.motion=new.motion}
            return copy
        }
    }
    static func repair(recipe:Recipe,url:URL,video:VideoDescriptor?,prepared:PreparedPhoto?) async throws -> Recipe {
        guard recipe.masks.contains(where:{ $0.kind.isAutomatic && $0.automatic?.matches(recipe) == false }) else { return recipe }
        var result = recipe
        let size:CGSize
        if let video { size = CGSize(width:video.width,height:video.height) }
        else if let prepared { size = CGSize(width:prepared.width,height:prepared.height) }
        else { let opened = try ImageEngine.open(url,maxDimension:1536);size = CGSize(width:opened.width,height:opened.height) }
        let required = MaskEngine.requiredIndices(recipe.masks)
        var input:CGImage?,created:[String:AutomaticMask] = [:]
        for i in result.masks.indices where result.masks[i].kind.isAutomatic {
            try Task.checkCancellation()
            guard let old = result.masks[i].automatic,!old.matches(recipe) else { continue }
            if old.temporal != nil {throw AutomaticSelectionEngine.error("Rebuild the People video matte after extending the kept clip or changing input conversion. Existing edits are preserved.")}
            if let moved = try reframe(old,to:recipe,sourceSize:size) {
                result.masks[i].automatic = moved
                if var motion = result.masks[i].motion,let previous = snapshot(motion.framing),sameField(previous,recipe) {
                    let field = PhotoFraming.orientedSize(size,recipe:recipe),a = PhotoFraming.window(in:field,recipe:previous),b = PhotoFraming.window(in:field,recipe:recipe)
                    motion.sourceWidth=size.width;motion.sourceHeight=size.height
                    let px=motion.pivotX ?? result.masks[i].centerX,py=motion.pivotY ?? result.masks[i].centerY
                    motion.pivotX=(a.minX+a.width*px-b.minX)/b.width
                    motion.pivotY=(b.maxY-(a.maxY-a.height*py))/b.height
                    motion.points = motion.points.map {var point=$0;point.x *= a.width/b.width;point.y *= a.height/b.height;return point}
                    motion.corrections = motion.corrections?.map {var point=$0;point.x *= a.width/b.width;point.y *= a.height/b.height;return point};motion.framing = MaskMotion.signature(recipe)
                    result.masks[i].motion = motion
                }
            } else {
                guard required.contains(i) else { continue }
                // Rotation/perspective or a different first video frame needs a fresh selection once.
                if input == nil { input = try await AutomaticSelectionEngine.input(url:url,video:video,recipe:recipe,prepared:prepared) }
                let kind = result.masks[i].kind
                let mode=old.selectionMode ?? .foreground,key=kind.rawValue+":"+mode.rawValue
                if mode == .picked {throw AutomaticSelectionEngine.error("Recreate this tapped-subject selection after changing its rotation or perspective. It will not be replaced with a selection of every subject.")}
                if created[key] == nil {created[key]=try await AutomaticSelectionEngine.analyze(input!,kind:kind,recipe:recipe,videoStart:video == nil ? nil:recipe.video.start,subjectMode:mode)}
                result.masks[i].automatic = created[key];result.masks[i].motion = nil
            }
        }
        return result
    }
}
