import SwiftUI

struct CropHandlesOverlay:View {
    @Bindable var session:EditSession
    let sourceSize:CGSize
    var editingChanged:(Bool)->Void = { _ in }
    @Environment(\.scenePhase) private var phase
    @State private var initial:Recipe?
    @State private var corner:CropCorner?
    @State private var moving = false
    var body:some View {
        GeometryReader { geometry in
            let size = PhotoFraming.orientedSize(sourceSize,recipe:session.recipe)
            let image = CropEditingGeometry.fit(size:size,container:geometry.size),scale = image.width/size.width
            let raw = CropEditingGeometry.rect(size:size,recipe:session.recipe)
            let frame = CGRect(x:image.minX+raw.minX*scale,y:image.minY+raw.minY*scale,width:raw.width*scale,height:raw.height*scale)
            ZStack {
                Path { p in p.addRect(image);p.addRect(frame) }.fill(.black.opacity(0.52),style:FillStyle(eoFill:true)).allowsHitTesting(false)
                Path { p in
                    p.addRect(frame)
                    for n in 1...2 {
                        let x = frame.minX+frame.width*Double(n)/3,y = frame.minY+frame.height*Double(n)/3
                        p.move(to:CGPoint(x:x,y:frame.minY));p.addLine(to:CGPoint(x:x,y:frame.maxY))
                        p.move(to:CGPoint(x:frame.minX,y:y));p.addLine(to:CGPoint(x:frame.maxX,y:y))
                    }
                }.stroke(.white.opacity(0.65),lineWidth:1).allowsHitTesting(false)
                ForEach(CropCorner.allCases) { handle in
                    let x = handle.left ? frame.minX : frame.maxX,y = handle.top ? frame.minY : frame.maxY
                    Path { p in
                        p.move(to:CGPoint(x:22+(handle.left ? 17 : -17),y:22));p.addLine(to:CGPoint(x:22,y:22));p.addLine(to:CGPoint(x:22,y:22+(handle.top ? 17 : -17)))
                    }.stroke(corner == handle && initial != nil ? StudioStyle.blue : .white,style:StrokeStyle(lineWidth:3,lineCap:.round,lineJoin:.round))
                        .frame(width:44,height:44).position(x:x,y:y)
                        .accessibilityElement().accessibilityLabel(handle.title).accessibilityIdentifier("cropCorner.\(handle.rawValue)")
                        .accessibilityAdjustableAction { direction in
                            let expand = direction == .increment ? 1.0 : -1.0,step = min(size.width,size.height)*0.025
                            session.change { $0 = CropEditingGeometry.resize($0,size:size,corner:handle,delta:CGSize(width:(handle.left ? -step : step)*expand,height:(handle.top ? -step : step)*expand)) }
                        }
                }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance:3).onChanged { value in
                    if initial == nil {
                        let inside = frame.insetBy(dx:min(16,frame.width/3),dy:min(16,frame.height/3))
                        if inside.contains(value.startLocation) { moving = true;corner = nil }
                        else {
                            let nearest = CropCorner.allCases.min { a,b in
                                distance(a,point:value.startLocation,frame:frame)<distance(b,point:value.startLocation,frame:frame)
                            }!
                            guard distance(nearest,point:value.startLocation,frame:frame)<=32 else { return }
                            corner = nearest;moving = false
                        }
                        initial = session.recipe;session.begin();editingChanged(true)
                    }
                    guard let initial else { return }
                    let delta = CGSize(width:value.translation.width/scale,height:value.translation.height/scale)
                    if let corner { session.recipe = CropEditingGeometry.resize(initial,size:size,corner:corner,delta:delta) }
                    else if moving { session.recipe = CropEditingGeometry.move(initial,size:size,delta:delta) }
                }.onEnded { _ in finish() })
                .accessibilityElement(children:.contain).accessibilityIdentifier("cropWorkspace")
        }
        .onDisappear { finish() }
        .onChange(of:phase) { _,value in if value != .active { finish() } }
    }
    private func distance(_ corner:CropCorner,point:CGPoint,frame:CGRect) -> Double {
        hypot(point.x-(corner.left ? frame.minX : frame.maxX),point.y-(corner.top ? frame.minY : frame.maxY))
    }
    private func finish() { if initial != nil { session.end();editingChanged(false) };initial = nil;corner = nil;moving = false }
}
