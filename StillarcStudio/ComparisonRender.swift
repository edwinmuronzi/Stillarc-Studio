import CoreImage

enum ComparisonRender {
    static func combine(original:CIImage,edited:CIImage,fraction:Double?) -> CIImage {
        guard let fraction,fraction.isFinite else { return edited }
        let extent = edited.extent,width = extent.width*min(1,max(0,fraction))
        guard width>0 else { return edited }
        if width>=extent.width { return original }
        return original.cropped(to:CGRect(x:extent.minX,y:extent.minY,width:width,height:extent.height)).composited(over:edited).cropped(to:extent)
    }
}
