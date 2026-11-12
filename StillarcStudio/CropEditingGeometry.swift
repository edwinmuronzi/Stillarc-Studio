import Foundation

enum CropCorner:String,CaseIterable,Identifiable {
    case topLeft,topRight,bottomLeft,bottomRight
    var id:String { rawValue }
    var left:Bool { self == .topLeft || self == .bottomLeft }
    var top:Bool { self == .topLeft || self == .topRight }
    var title:String { switch self { case .topLeft:"Top left crop corner";case .topRight:"Top right crop corner";case .bottomLeft:"Bottom left crop corner";case .bottomRight:"Bottom right crop corner" } }
}
enum CropEditingGeometry {
    static func workspace(_ recipe:Recipe) -> Recipe {
        var r = recipe;r.crop = .original;r.cropX = 0.5;r.cropY = 0.5;r.geometry.width = 1;r.geometry.height = 1;r.geometry.cropScale = 1;r.masks = []
        return r
    }
    /// Top-left coordinates in the full oriented/straightened frame.
    static func rect(size:CGSize,recipe:Recipe) -> CGRect {
        let w = PhotoFraming.window(in:size,recipe:recipe)
        return CGRect(x:w.minX,y:size.height-w.maxY,width:w.width,height:w.height)
    }
    static func fit(size:CGSize,container:CGSize) -> CGRect {
        let bounds = CGRect(origin:.zero,size:container).insetBy(dx:22,dy:22)
        let scale = min(max(1,bounds.width)/max(1,size.width),max(1,bounds.height)/max(1,size.height))
        return CGRect(x:(container.width-size.width*scale)/2,y:(container.height-size.height*scale)/2,width:size.width*scale,height:size.height*scale)
    }
    static func apply(_ rectangle:CGRect,size:CGSize,recipe:Recipe) -> Recipe {
        var r = recipe
        if r.crop == .free {
            r.geometry.width = min(1,max(0.1,rectangle.width/size.width));r.geometry.height = min(1,max(0.1,rectangle.height/size.height));r.geometry.cropScale = 1
        } else {
            let ratio = r.crop.ratio ?? size.width/size.height
            let maximum = min(size.width,size.height*ratio)
            r.geometry.cropScale = min(1,max(0.1,rectangle.width/maximum))
        }
        let window = PhotoFraming.window(in:size,recipe:r),xRoom = size.width-window.width,yRoom = size.height-window.height
        r.cropX = xRoom>0.001 ? min(1,max(0,rectangle.minX/xRoom)) : 0.5
        r.cropY = yRoom>0.001 ? min(1,max(0,rectangle.minY/yRoom)) : 0.5
        return r
    }
    static func resize(_ initial:Recipe,size:CGSize,corner:CropCorner,delta:CGSize) -> Recipe {
        guard size.width>0,size.height>0,delta.width.isFinite,delta.height.isFinite else { return initial }
        let r = rect(size:size,recipe:initial)
        let anchor = CGPoint(x:corner.left ? r.maxX : r.minX,y:corner.top ? r.maxY : r.minY)
        let original = CGPoint(x:corner.left ? r.minX : r.maxX,y:corner.top ? r.minY : r.maxY)
        let x = original.x+delta.width,y = original.y+delta.height
        let dx = corner.left ? anchor.x-x : x-anchor.x,dy = corner.top ? anchor.y-y : y-anchor.y
        let availableX = corner.left ? anchor.x : size.width-anchor.x,availableY = corner.top ? anchor.y : size.height-anchor.y
        let width:Double,height:Double
        if initial.crop == .free {
            width = min(availableX,max(size.width*0.1,dx));height = min(availableY,max(size.height*0.1,dy))
        } else {
            let ratio = initial.crop.ratio ?? size.width/size.height
            let maximum = min(size.width,size.height*ratio),limit = min(availableX,availableY*ratio)
            let projected = (dx+dy/ratio)/(1+1/(ratio*ratio))
            width = min(limit,max(maximum*0.1,projected));height = width/ratio
        }
        return apply(CGRect(x:corner.left ? anchor.x-width : anchor.x,y:corner.top ? anchor.y-height : anchor.y,width:width,height:height),size:size,recipe:initial)
    }
    static func move(_ initial:Recipe,size:CGSize,delta:CGSize) -> Recipe {
        guard delta.width.isFinite,delta.height.isFinite else { return initial }
        var r = rect(size:size,recipe:initial)
        r.origin.x = min(max(0,size.width-r.width),max(0,r.minX+delta.width))
        r.origin.y = min(max(0,size.height-r.height),max(0,r.minY+delta.height))
        return apply(r,size:size,recipe:initial)
    }
}
