import SwiftUI

/// Preview-only: normalized mask coordinates and export resolution never change.
struct MaskViewport:Equatable {
    var scale=1.0
    var offset=CGSize.zero
    func rect(size:CGSize,container:CGSize)->CGRect {
        let factor=min(container.width/max(1,size.width),container.height/max(1,size.height))
        let fit=CGRect(x:(container.width-size.width*factor)/2,y:(container.height-size.height*factor)/2,width:size.width*factor,height:size.height*factor)
        return CGRect(x:container.width/2+(fit.minX-container.width/2)*scale+offset.width,y:container.height/2+(fit.minY-container.height/2)*scale+offset.height,width:fit.width*scale,height:fit.height*scale)
    }
    static func bounded(_ offset:CGSize,scale:Double,container:CGSize)->CGSize {
        CGSize(width:min(container.width*(scale-1)/2,max(-container.width*(scale-1)/2,offset.width)),height:min(container.height*(scale-1)/2,max(-container.height*(scale-1)/2,offset.height)))
    }
}
struct MaskViewportModifier:ViewModifier {
    let viewport:MaskViewport
    func body(content:Content)->some View {content.scaleEffect(viewport.scale).offset(viewport.offset)}
}
