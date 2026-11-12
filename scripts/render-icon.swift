import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Resample the user-approved master; do not regenerate a different logo.
let dark=CommandLine.arguments.contains("--dark")
let edge=CommandLine.arguments.contains("--brand") ? 256:1024
let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
let master=root.appendingPathComponent("Design/Icons/Approved/Studio-\(dark ? "Dark":"Light").png")
guard let source=CGImageSourceCreateWithURL(master as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else {fatalError("Approved icon master missing")}
let space=CGColorSpace(name:CGColorSpace.sRGB)!
let context=CGContext(data:nil,width:edge,height:edge,bitsPerComponent:8,bytesPerRow:edge*4,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.draw(image,in:CGRect(x:0,y:0,width:edge,height:edge))
let url=URL(fileURLWithPath:CommandLine.arguments[1]),output=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(output,context.makeImage()!,nil)
guard CGImageDestinationFinalize(output) else {fatalError("Icon PNG encoding failed")}
