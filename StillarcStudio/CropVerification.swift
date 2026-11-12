#if DEBUG
import CoreImage
import Foundation

enum CropVerification {
    static func run() throws -> [String:Any] {
        func require(_ value:Bool,_ message:String) throws { if !value { throw NSError(domain:"CropHandles",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        let legacy = try JSONDecoder().decode(GeometrySettings.self,from:Data("{\"width\":0.7,\"height\":0.8,\"flipHorizontal\":true,\"horizontal\":0.1}".utf8))
        try require(legacy.cropScale == 1 && legacy.width == 0.7 && legacy.flipHorizontal,"Legacy framing migration")
        let base = Recipe(),g = base.geometry
        let oldSignature = base.crop.rawValue+":"+[Double(base.rotation),base.straighten,base.cropX,base.cropY,g.width,g.height,g.flipHorizontal ? 1:0,g.flipVertical ? 1:0,g.horizontal,g.vertical].map { String($0) }.joined(separator:",")
        try require(MaskMotion.signature(base) == oldSignature,"Existing mask signature changed")
        var checks = 0
        for source in [CGSize(width:4000,height:3000),CGSize(width:941,height:1672),CGSize(width:3840,height:2160)] {
            for rotation in 0..<4 { for crop in Crop.allCases { for corner in CropCorner.allCases {
                var r = Recipe();r.crop = crop;r.rotation = rotation;r.straighten = 4;r.cropX = 0.3;r.cropY = 0.7
                r.geometry.cropScale = 0.7;r.geometry.width = 0.7;r.geometry.height = 0.6
                let size = PhotoFraming.orientedSize(source,recipe:r),before = CropEditingGeometry.rect(size:size,recipe:r)
                let changed = CropEditingGeometry.resize(r,size:size,corner:corner,delta:CGSize(width:corner.left ? 100:-100,height:corner.top ? 100:-100))
                let after = CropEditingGeometry.rect(size:size,recipe:changed)
                try require(after.width < before.width && after.height < before.height,"Corner did not shrink")
                let ax = corner.left ? before.maxX:before.minX,ay = corner.top ? before.maxY:before.minY
                try require(abs(ax-(corner.left ? after.maxX:after.minX))<=2 && abs(ay-(corner.top ? after.maxY:after.minY))<=2,"Opposite corner drift")
                if crop != .free { let ratio = crop.ratio ?? size.width/size.height;try require(abs(after.width-after.height*ratio)<ratio+1,"Locked aspect ratio changed") }
                for delta in [CGSize(width:100000,height:100000),CGSize(width:-100000,height:-100000)] {
                    for edited in [CropEditingGeometry.move(changed,size:size,delta:delta),CropEditingGeometry.resize(changed,size:size,corner:corner,delta:delta)] {
                        let rect = CropEditingGeometry.rect(size:size,recipe:edited)
                        try require(rect.minX>=0 && rect.minY>=0 && rect.maxX<=size.width && rect.maxY<=size.height && rect.width>0 && rect.height>0,"Crop escaped source")
                    }
                }
                try require(CropEditingGeometry.workspace(r) == CropEditingGeometry.workspace(changed),"Dragging rerenders full-image workspace")
                let reopened = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(changed));try require(reopened == changed,"Crop save/reopen")
                let image = CIImage(color:.white).cropped(to:CGRect(origin:.zero,size:source))
                try require(PhotoFraming.apply(image,recipe:changed).extent.size == after.size,"Export crop differs from handles")
                checks += 1
            } } }
        }
        var scaled = Recipe();scaled.geometry.cropScale = 0.5
        try require(MaskMotion.signature(scaled) != oldSignature,"Scale did not invalidate mask tracking")
        try require(scaled.hasAdjustments(in:.crop) && scaled.colorPreset.geometry.isNeutral,"Crop dot / preset isolation")
        scaled.reset(.crop);try require(scaled == base,"Crop reset")
        let r = CropEditingGeometry.resize(base,size:CGSize(width:4000,height:3000),corner:.bottomRight,delta:CGSize(width:CGFloat.nan,height:1))
        try require(r == base,"Nonfinite drag validation")
        return ["passed":true,"cornerFixtures":checks,"legacyGeometryMigration":true,"legacyMaskSignaturePreserved":true,"exportGeometryMatches":true,"workspaceUnchangedDuringDrag":true,"boundsAndAspectLocks":true,"persistenceAndReset":true]
    }
}
#endif
