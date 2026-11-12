import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Resolution-independent paths shared by the two icon appearances.
let dark=CommandLine.arguments.contains("--dark")
let space=CGColorSpace(name:CGColorSpace.sRGB)!
let c=CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat,_ a:CGFloat=1) -> CGColor {CGColor(colorSpace:space,components:[r,g,b,a])!}
let top=dark ? color(0.055,0.075,0.12):color(0.98,0.99,1)
let bottom=dark ? color(0.012,0.019,0.035):color(0.78,0.85,0.96)
let blue=color(0.18,0.49,1),cyan=color(0.38,0.76,1,0.75)
c.drawLinearGradient(CGGradient(colorsSpace:space,colors:[bottom,top] as CFArray,locations:[0,1])!,start:CGPoint(x:512,y:0),end:CGPoint(x:512,y:1024),options:[])
c.setStrokeColor(dark ? color(1,1,1,0.14):color(0.18,0.49,1,0.2));c.setLineWidth(2);c.strokeEllipse(in:CGRect(x:163,y:163,width:698,height:698))
c.setLineCap(.round);c.setLineJoin(.round)
for (a,b) in [(108.0,252.0),(288.0,432.0)] {
    c.saveGState();c.setShadow(offset:.zero,blur:24,color:color(0.18,0.49,1,dark ? 0.3:0.15));c.setLineWidth(43);c.setStrokeColor(blue)
    c.addArc(center:CGPoint(x:512,y:512),radius:332,startAngle:a * .pi/180,endAngle:b * .pi/180,clockwise:false);c.strokePath();c.restoreGState()
    c.setLineWidth(4);c.setStrokeColor(cyan);c.addArc(center:CGPoint(x:512,y:512),radius:344,startAngle:(a+3) * .pi/180,endAngle:(b-3) * .pi/180,clockwise:false);c.strokePath()
}
c.move(to:CGPoint(x:643,y:670))
c.addCurve(to:CGPoint(x:385,y:653),control1:CGPoint(x:573,y:748),control2:CGPoint(x:392,y:744))
c.addCurve(to:CGPoint(x:506,y:513),control1:CGPoint(x:351,y:580),control2:CGPoint(x:429,y:544))
c.addCurve(to:CGPoint(x:639,y:376),control1:CGPoint(x:584,y:482),control2:CGPoint(x:674,y:448))
c.addCurve(to:CGPoint(x:381,y:352),control1:CGPoint(x:613,y:272),control2:CGPoint(x:444,y:280))
c.setLineWidth(64);c.setStrokeColor(dark ? color(0.91,0.96,1):color(0.055,0.16,0.31));c.strokePath()
let image=c.makeImage()!,url=URL(fileURLWithPath:CommandLine.arguments[1])
let output=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(output,image,nil);guard CGImageDestinationFinalize(output) else {fatalError("PNG encoding failed")}
