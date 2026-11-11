import AppKit
let size = 1024
let image = NSImage(size: NSSize(width: size,height: size))
image.lockFocus()
NSColor(calibratedRed: 0.025,green: 0.03,blue: 0.045,alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0,y: 0,width: size,height: size)).fill()
let blue = NSColor(calibratedRed: 0.25,green: 0.52,blue: 1,alpha: 1)
blue.setStroke()
for angles in [(12.0,168.0),(192.0,348.0)] {
 let arc = NSBezierPath();arc.lineWidth = 38;arc.lineCapStyle = .round
 arc.appendArc(withCenter: NSPoint(x: 512,y: 512),radius: 350,startAngle: angles.0,endAngle: angles.1)
 arc.stroke()
}
NSColor.white.withAlphaComponent(0.2).setStroke()
let ring = NSBezierPath(ovalIn:NSRect(x: 242,y:242,width:540,height:540));ring.lineWidth = 2;ring.stroke()
let font = NSFont(name: "Baskerville",size: 510) ?? NSFont.systemFont(ofSize: 510)
let text = NSAttributedString(string: "S",attributes:[.font:font,.foregroundColor:NSColor.white])
let measured = text.size(); text.draw(at: NSPoint(x:(1024-measured.width)/2,y:(1024-measured.height)/2+20))
image.unlockFocus()
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: size,pixelsHigh: size,bitsPerSample: 8,samplesPerPixel: 3,hasAlpha: false,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 0,bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: NSRect(x: 0,y: 0,width: size,height: size))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png,properties: [:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
