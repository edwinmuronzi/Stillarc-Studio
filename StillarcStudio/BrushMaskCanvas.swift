import SwiftUI

struct BrushMaskCanvas:View {
    @Bindable var session:EditSession
    let id:UUID
    let sourceSize:CGSize
    var viewport=MaskViewport()
    let erase:Bool
    @State private var strokeID:UUID?
    @State private var cursor:CGPoint?
    var body:some View {
        GeometryReader { geometry in
            if let layer = session.recipe.masks.first(where:{ $0.id == id }) {
                let size = PhotoFraming.window(in:PhotoFraming.orientedSize(sourceSize,recipe:session.recipe),recipe:session.recipe).size
                let visible=viewport.rect(size:size,container:geometry.size)
                let width=visible.width,height=visible.height,left=visible.minX,top=visible.minY
                let rect = CGRect(x:left,y:top,width:width,height:height)
                let hit = Path(rect)
                Color.clear.contentShape(hit,eoFill:true)
                    .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("comparisonPreview")).onChanged { value in
                        guard width>0,height>0,let index = session.recipe.masks.firstIndex(where:{ $0.id == id }) else { return }
                        let point = BrushPoint(x:(value.location.x-left)/width,y:(value.location.y-top)/height).validated()
                        cursor = CGPoint(x:left+point.x*width,y:top+point.y*height)
                        if strokeID == nil {
                            session.begin()
                            if session.recipe.masks[index].brush == nil { session.recipe.masks[index].brush = BrushDrawing() }
                            guard (session.recipe.masks[index].brush?.strokes.count ?? 0)<64 else { return }
                            session.begin();strokeID = session.recipe.masks[index].brush?.begin(point:point,radius:layer.width,feather:layer.feather,erase:erase != layer.inverted)
                        } else if let strokeID,let last = session.recipe.masks[index].brush?.strokes.last?.points.last {
                            let dx = (point.x-last.x)*width,dy = (point.y-last.y)*height
                            if hypot(dx,dy)>=max(0.5,layer.width*min(width,height)*0.08) { session.recipe.masks[index].brush?.append(point,stroke:strokeID) }
                        }
                    }.onEnded { value in
                        if let strokeID,let index = session.recipe.masks.firstIndex(where:{ $0.id == id }),width>0,height>0 {
                            let point = BrushPoint(x:(value.location.x-left)/width,y:(value.location.y-top)/height).validated()
                            session.recipe.masks[index].brush?.append(point,stroke:strokeID)
                        }
                        session.end();strokeID = nil;cursor = nil
                    })
                    .accessibilityValue("\(layer.brush?.strokes.count ?? 0) strokes").accessibilityIdentifier("brushMaskCanvas").accessibilityLabel("Paint mask on the image. Select Eraser to remove painted areas; undo removes a complete stroke.")
                if let cursor {
                    Circle().stroke(.white,style:StrokeStyle(lineWidth:1,dash:erase ? [3,3] : []))
                        .frame(width:max(2,layer.width*min(width,height)*2),height:max(2,layer.width*min(width,height)*2)).position(cursor).allowsHitTesting(false)
                }
            }
        }.onDisappear { session.end();strokeID = nil;cursor = nil }
    }
}
