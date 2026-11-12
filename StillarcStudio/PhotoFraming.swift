import CoreImage

// One geometry implementation for the preview, comparison and full-size export.
enum PhotoFraming {
    static func straightenedSize(_ size: CGSize, degrees: Double) -> CGSize {
        guard abs(degrees) > 0.000001 else { return size }
        let angle = abs(degrees) * .pi / 180
        let scale = 1 / (cos(angle) + max(size.width / size.height, size.height / size.width) * sin(angle))
        // Inset slightly to keep interpolation from sampling outside the rotated source.
        return CGSize(width: max(1,floor(size.width * scale - 2)),height: max(1,floor(size.height * scale - 2)))
    }
    static func orientedSize(_ size: CGSize, recipe: Recipe) -> CGSize {
        let rotated = recipe.rotation % 2 == 0 ? size : CGSize(width: size.height,height: size.width)
        return straightenedSize(rotated,degrees: recipe.straighten)
    }
    static func window(in size: CGSize, recipe: Recipe) -> CGRect {
        let width:Double,height:Double
        if recipe.crop == .free {
            let g = recipe.geometry.validated();width = max(1,floor(size.width*g.width));height = max(1,floor(size.height*g.height))
        } else if let ratio = recipe.crop.ratio {
            width = max(1,floor(min(size.width,size.height * ratio)*recipe.geometry.validated().cropScale));height = max(1,floor(min(size.height,size.width / ratio)*recipe.geometry.validated().cropScale))
        } else { let scale = recipe.geometry.validated().cropScale;width = max(1,floor(size.width*scale));height = max(1,floor(size.height*scale)) }
        return CGRect(x: floor((size.width-width) * min(1,max(0,recipe.cropX))),y: floor((size.height-height) * (1-min(1,max(0,recipe.cropY)))),width: width,height: height)
    }
    static func apply(_ source: CIImage, recipe: Recipe) -> CIImage {
        var image = source
        let rotation = ((recipe.rotation % 4) + 4) % 4
        if rotation != 0 { image = image.oriented(forExifOrientation: [1,6,3,8][rotation]) }
        image = image.transformed(by: .init(translationX: -image.extent.minX,y: -image.extent.minY))
        let g = recipe.geometry.validated(),size = image.extent.size
        if g.flipHorizontal { image = image.transformed(by:.init(a:-1,b:0,c:0,d:1,tx:size.width,ty:0)) }
        if g.flipVertical { image = image.transformed(by:.init(a:1,b:0,c:0,d:-1,tx:0,ty:size.height)) }
        if g.horizontal != 0 || g.vertical != 0 {
            let w = size.width,h = size.height
            let left = max(0,g.horizontal)*h,right = max(0,-g.horizontal)*h
            let top = max(0,g.vertical)*w,bottom = max(0,-g.vertical)*w
            let corrected = image.applyingFilter("CIPerspectiveCorrection",parameters:["inputTopLeft":CIVector(x:top,y:h-left),"inputTopRight":CIVector(x:w-top,y:h-right),"inputBottomLeft":CIVector(x:bottom,y:left),"inputBottomRight":CIVector(x:w-bottom,y:right),"inputCrop":true])
            if corrected.extent.width>0 && corrected.extent.height>0 && !corrected.extent.isInfinite {
                image = corrected.transformed(by:.init(translationX:-corrected.extent.minX,y:-corrected.extent.minY))
                    .transformed(by:.init(scaleX:w/corrected.extent.width,y:h/corrected.extent.height)).cropped(to:CGRect(origin:.zero,size:size))
            }
        }
        if abs(recipe.straighten) > 0.000001 {
            let extent = image.extent
            let size = straightenedSize(extent.size,degrees: recipe.straighten)
            image = image.transformed(by: .init(translationX: -extent.midX,y: -extent.midY))
                .transformed(by: .init(rotationAngle: recipe.straighten * .pi / 180))
                .cropped(to: CGRect(x: floor(-size.width/2),y: floor(-size.height/2),width: size.width,height: size.height))
            image = image.transformed(by: .init(translationX: -image.extent.minX,y: -image.extent.minY))
        }
        image = image.cropped(to: window(in: image.extent.size,recipe: recipe))
        return image.transformed(by: .init(translationX: -image.extent.minX,y: -image.extent.minY))
    }
}
