import Foundation
import CryptoKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Immutable, shared between undo states. Equality never scans the cube while dragging.
final class LUTAsset: Codable, Equatable, @unchecked Sendable {
    enum Kind:String,Codable,Sendable {case cube3D,curve1D}
    let kind:Kind
    private let curveData:Data?
    var detail:String {kind == .curve1D ? "1D · \(dimension) points per channel":"3D · \(dimension) × \(dimension) × \(dimension)"}
    let name: String
    let dimension: Int
    let domainMin: [Float]
    let domainMax: [Float]
    let cube: Data
    let fingerprint: String
    private enum CodingKeys: String, CodingKey { case kind, name, dimension, domainMin, domainMax, cube }
    static func == (a: LUTAsset, b: LUTAsset) -> Bool { a === b || (a.fingerprint == b.fingerprint && a.name == b.name) }
    init(name: String, dimension: Int, domainMin: [Float], domainMax: [Float], cube: Data,kind:Kind = .cube3D) throws {
        guard (kind == .curve1D ? (2...4096):(2...65)).contains(dimension), domainMin.count == 3, domainMax.count == 3,
              zip(domainMin,domainMax).allSatisfy({ $0.isFinite && $1.isFinite && abs($0) <= 64 && abs($1) <= 64 && $1-$0 >= 0.000001 }),
              cube.count == (kind == .curve1D ? dimension:dimension*dimension*dimension)*16 else { throw LUTError.invalid }
        let valid = cube.withUnsafeBytes { bytes in
            stride(from:0,to:bytes.count,by:16).allSatisfy { offset in
                (0..<3).allSatisfy { i in let v = bytes.loadUnaligned(fromByteOffset:offset+i*4,as:Float.self); return v.isFinite && abs(v) <= 64 } && bytes.loadUnaligned(fromByteOffset:offset+12,as:Float.self) == 1
            }
        }
        guard valid else { throw LUTError.invalid }
        self.kind=kind
        if kind == .curve1D {
            var values=[Float]();values.reserveCapacity(dimension*3)
            cube.withUnsafeBytes {bytes in for n in 0..<dimension {for c in 0..<3 {values.append(bytes.loadUnaligned(fromByteOffset:n*16+c*4,as:Float.self))}}}
            curveData=values.withUnsafeBytes {Data($0)}
        } else {curveData=nil}
        self.name = String(name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(100))
        self.dimension = dimension; self.domainMin = domainMin; self.domainMax = domainMax; self.cube = cube
        var digest = SHA256();if kind == .curve1D {digest.update(data:Data("1D:".utf8))}; digest.update(data:cube)
        digest.update(data:Data("\(dimension):\(domainMin):\(domainMax)".utf8))
        fingerprint = digest.finalize().map { String(format:"%02x",$0) }.joined()
    }
    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        let data = try c.decode(Data.self,forKey:.cube)
        guard data.count <= 65*65*65*16 else { throw LUTError.invalid }
        try self.init(name:c.decode(String.self,forKey:.name),dimension:c.decode(Int.self,forKey:.dimension),domainMin:c.decode([Float].self,forKey:.domainMin),domainMax:c.decode([Float].self,forKey:.domainMax),cube:data,kind:c.decodeIfPresent(Kind.self,forKey:.kind) ?? .cube3D)
    }
    static func read(_ url: URL) throws -> LUTAsset {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        guard url.pathExtension.lowercased() == "cube" else { throw LUTError.invalid }
        let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 20_000_000 else { throw LUTError.tooLarge }
        let data = try Data(contentsOf:url,options:.mappedIfSafe)
        guard data.count <= 20_000_000, let text = String(data:data,encoding:.utf8) else { throw LUTError.invalid }
        return try parse(text,name:url.deletingPathExtension().lastPathComponent)
    }
    /// Standalone 1D and red-fastest 3D creative .cube tables; combined tables are rejected.
    static func parse(_ text: String, name: String) throws -> LUTAsset {
        guard text.utf8.count <= 20_000_000 else { throw LUTError.tooLarge }
        var dimension: Int?, kind=Kind.cube3D, title = name, low: [Float] = [0,0,0], high: [Float] = [1,1,1]
        var rangeKind:Kind?
        var values = [Float](), seenMin = false, seenMax = false, started = false
        for raw in text.split(whereSeparator: \.isNewline) {
            var quoted=false
            let comment=raw.firstIndex {character in if character == "\"" {quoted.toggle()};return character == "#" && !quoted}
            let line=String(comment.map {raw[..<$0]} ?? raw[...]).trimmingCharacters(in:.whitespacesAndNewlines.union(.init(charactersIn:"\u{feff}")))
            if line.isEmpty { continue }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let first = fields.first else { continue }
            if first == "TITLE" {
                guard !started else { throw LUTError.invalid }
                let value = line.dropFirst(5).trimmingCharacters(in:.whitespaces)
                guard value.first == "\"", value.last == "\"", value.count >= 2 else { throw LUTError.invalid }
                title = String(value.dropFirst().dropLast()); continue
            }
            if first == "LUT_3D_SIZE" || first == "LUT_1D_SIZE" {
                kind=first == "LUT_1D_SIZE" ? .curve1D:.cube3D
                guard !started,dimension == nil,(rangeKind == nil || rangeKind == kind),fields.count==2,let n=Int(fields[1]),(kind == .curve1D ? (2...4096):(2...65)).contains(n) else {throw LUTError.invalid}
                dimension=n;values.reserveCapacity((kind == .curve1D ? n:n*n*n)*4);continue
            }
            if first == "LUT_1D_INPUT_RANGE" || first == "LUT_3D_INPUT_RANGE" {
                let expected:Kind=first == "LUT_1D_INPUT_RANGE" ? .curve1D:.cube3D
                guard !started,!seenMin,!seenMax,fields.count==3,(dimension == nil || kind == expected),let minimum=Float(fields[1]),let maximum=Float(fields[2]),minimum.isFinite,maximum.isFinite else {throw LUTError.invalid}
                rangeKind=expected;low=Array(repeating:minimum,count:3);high=Array(repeating:maximum,count:3);seenMin=true;seenMax=true;continue
            }
            if first == "DOMAIN_MIN" || first == "DOMAIN_MAX" {
                guard !started, fields.count == 4 else { throw LUTError.invalid }
                let triplet = fields.dropFirst().compactMap { Float($0) }
                guard triplet.count == 3, triplet.allSatisfy(\.isFinite) else { throw LUTError.invalid }
                if first == "DOMAIN_MIN" { guard !seenMin else { throw LUTError.invalid }; low = triplet; seenMin = true }
                else { guard !seenMax else { throw LUTError.invalid }; high = triplet; seenMax = true }
                continue
            }
            guard let n = dimension, fields.count == 3, values.count < (kind == .curve1D ? n:n*n*n)*4 else { throw LUTError.invalid }
            let triplet = fields.compactMap { Float($0) }
            guard triplet.count == 3, triplet.allSatisfy({ $0.isFinite && abs($0) <= 64 }) else { throw LUTError.invalid }
            started = true; values.append(contentsOf:triplet); values.append(1)
        }
        guard let n = dimension, values.count == (kind == .curve1D ? n:n*n*n)*4 else { throw LUTError.invalid }
        return try values.withUnsafeBytes { try LUTAsset(name:title,dimension:n,domainMin:low,domainMax:high,cube:Data($0),kind:kind) }
    }
    func apply(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        // The app works in linear sRGB. .cube coordinates and values here are display sRGB.
        var encoded = image.applyingFilter("CILinearToSRGBToneCurve")
        if domainMin != [0,0,0] || domainMax != [1,1,1] {
            let scale = (0..<3).map { Double(1 / (domainMax[$0]-domainMin[$0])) }
            encoded = encoded.applyingFilter("CIColorMatrix",parameters:[
                "inputRVector":CIVector(x:scale[0],y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:scale[1],z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:scale[2],w:0),
                "inputBiasVector":CIVector(x:-Double(domainMin[0])*scale[0],y:-Double(domainMin[1])*scale[1],z:-Double(domainMin[2])*scale[2],w:0)])
        }
        let mapped:CIImage
        if let curveData {
            let filter=CIFilter.colorCurves()
            filter.inputImage=encoded.applyingFilter("CIColorClamp",parameters:["inputMinComponents":CIVector(x:0,y:0,z:0,w:0),"inputMaxComponents":CIVector(x:1,y:1,z:1,w:1)])
            filter.curvesData=curveData;filter.curvesDomain=CIVector(x:0,y:1)
            // Values are already display-encoded above; avoid applying a second sRGB transfer.
            filter.colorSpace=ImageEngine.working
            mapped=filter.outputImage ?? encoded
        } else {mapped=encoded.applyingFilter("CIColorCube",parameters:["inputCubeDimension":dimension,"inputCubeData":cube])}
        let graded=mapped.applyingFilter("CISRGBToneCurveToLinear")
        if amount >= 1 { return graded }
        return image.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:graded,kCIInputTimeKey:amount])
    }
}
enum LUTError: LocalizedError {
    case invalid, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: "Use a display-sRGB creative .cube LUT: standalone 1D (2–4096 points) or 3D (2–65 per side). Combined 1D/3D files are not supported; use Input for Log conversion."
        case .tooLarge: "This LUT is too large. Choose a .cube file under 20 MB: up to 4096 points for 1D or 65 per side for 3D."
        }
    }
}

/// At most two extra layers after the original LUT; immutable cubes are shared by history.
struct LUTLayer:Codable,Equatable,Identifiable,Sendable {
    var id=UUID()
    var asset:LUTAsset
    var amount=1.0
    var enabled=true
    func validated()->Self {var r=self;r.amount=amount.isFinite ? min(1,max(0,amount)):1;return r}
}
