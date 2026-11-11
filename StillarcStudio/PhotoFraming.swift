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
        guard let ratio = recipe.crop.ratio else { return CGRect(origin: .zero,size: size) }
        let width = max(1,floor(min(size.width,size.height * ratio)))
        let height = max(1,floor(min(size.height,size.width / ratio)))
        return CGRect(x: floor((size.width-width) * min(1,max(0,recipe.cropX))),y: floor((size.height-height) * (1-min(1,max(0,recipe.cropY)))),width: width,height: height)
    }
    static func apply(_ source: CIImage, recipe: Recipe) -> CIImage {
        var image = source
        let rotation = ((recipe.rotation % 4) + 4) % 4
        if rotation != 0 { image = image.oriented(forExifOrientation: [1,6,3,8][rotation]) }
        image = image.transformed(by: .init(translationX: -image.extent.minX,y: -image.extent.minY))
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
