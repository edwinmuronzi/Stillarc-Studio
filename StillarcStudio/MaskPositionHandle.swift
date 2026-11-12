import SwiftUI

struct MaskPositionHandle:View {
    @Bindable var session:EditSession
    let id:UUID
    let sourceSize:CGSize
    var viewport=MaskViewport()
    var body:some View {
        GeometryReader { geometry in
            if let layer = session.recipe.masks.first(where:{ $0.id == id }) {
                let framed = PhotoFraming.window(in:PhotoFraming.orientedSize(sourceSize,recipe:session.recipe),recipe:session.recipe).size
                let visible=viewport.rect(size:framed,container:geometry.size)
                let width=visible.width,height=visible.height,left=visible.minX,top=visible.minY
                Image(systemName:"plus").font(.caption.bold()).foregroundStyle(.white).frame(width:36,height:36).background(.black.opacity(0.5),in:Circle()).overlay(Circle().stroke(.white.opacity(0.8),lineWidth:1))
                    .position(x:left+layer.centerX*width,y:top+layer.centerY*height)
                    .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("comparisonPreview")).onChanged { value in
                        guard let index = session.recipe.masks.firstIndex(where:{ $0.id == id }) else { return }
                        session.begin();session.recipe.masks[index].centerX = min(1,max(0,(value.location.x-left)/width));session.recipe.masks[index].centerY = min(1,max(0,(value.location.y-top)/height))
                    }.onEnded { _ in session.end() })
                    .accessibilityLabel("Mask center; use horizontal and vertical position sliders for precise adjustment")
            }
        }
    }
}
