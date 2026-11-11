import Foundation
import CryptoKit
import CoreImage

/// Immutable, shared between undo states. Equality never scans the cube while dragging.
final class LUTAsset: Codable, Equatable, @unchecked Sendable {
    let name: String
    let dimension: Int
    let domainMin: [Float]
    let domainMax: [Float]
    let cube: Data
    let fingerprint: String
    private enum CodingKeys: String, CodingKey { case name, dimension, domainMin, domainMax, cube }
    static func == (a: LUTAsset, b: LUTAsset) -> Bool { a === b || (a.fingerprint == b.fingerprint && a.name == b.name) }
    init(name: String, dimension: Int, domainMin: [Float], domainMax: [Float], cube: Data) throws {
        guard (2...65).contains(dimension), domainMin.count == 3, domainMax.count == 3,
              zip(domainMin,domainMax).allSatisfy({ $0.isFinite && $1.isFinite && abs($0) <= 64 && abs($1) <= 64 && $1-$0 >= 0.000001 }),
              cube.count == dimension*dimension*dimension*16 else { throw LUTError.invalid }
        let valid = cube.withUnsafeBytes { bytes in
            stride(from:0,to:bytes.count,by:16).allSatisfy { offset in
                (0..<3).allSatisfy { i in let v = bytes.loadUnaligned(fromByteOffset:offset+i*4,as:Float.self); return v.isFinite && abs(v) <= 64 } && bytes.loadUnaligned(fromByteOffset:offset+12,as:Float.self) == 1
            }
        }
        guard valid else { throw LUTError.invalid }
        self.name = String(name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(100))
        self.dimension = dimension; self.domainMin = domainMin; self.domainMax = domainMax; self.cube = cube
        var digest = SHA256(); digest.update(data:cube)
        digest.update(data:Data("\(dimension):\(domainMin):\(domainMax)".utf8))
        fingerprint = digest.finalize().map { String(format:"%02x",$0) }.joined()
    }
    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        let data = try c.decode(Data.self,forKey:.cube)
        guard data.count <= 65*65*65*16 else { throw LUTError.invalid }
        try self.init(name:c.decode(String.self,forKey:.name),dimension:c.decode(Int.self,forKey:.dimension),domainMin:c.decode([Float].self,forKey:.domainMin),domainMax:c.decode([Float].self,forKey:.domainMax),cube:data)
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
    /// Standard red-fastest 3D .cube tables; shapers/Log transforms are deliberately rejected.
    static func parse(_ text: String, name: String) throws -> LUTAsset {
        guard text.utf8.count <= 20_000_000 else { throw LUTError.tooLarge }
        var dimension: Int?, title = name, low: [Float] = [0,0,0], high: [Float] = [1,1,1]
        var values = [Float](), seenMin = false, seenMax = false, started = false
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.split(separator:"#",maxSplits:1,omittingEmptySubsequences:false)[0].trimmingCharacters(in:.whitespacesAndNewlines.union(.init(charactersIn:"\u{feff}")))
            if line.isEmpty { continue }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let first = fields.first else { continue }
            if first == "TITLE" {
                guard !started else { throw LUTError.invalid }
                let value = line.dropFirst(5).trimmingCharacters(in:.whitespaces)
                guard value.first == "\"", value.last == "\"", value.count >= 2 else { throw LUTError.invalid }
                title = String(value.dropFirst().dropLast()); continue
            }
            if first == "LUT_3D_SIZE" {
                guard !started, dimension == nil, fields.count == 2, let n = Int(fields[1]), (2...65).contains(n) else { throw LUTError.invalid }
                dimension = n; values.reserveCapacity(n*n*n*4); continue
            }
            if first == "DOMAIN_MIN" || first == "DOMAIN_MAX" {
                guard !started, fields.count == 4 else { throw LUTError.invalid }
                let triplet = fields.dropFirst().compactMap { Float($0) }
                guard triplet.count == 3, triplet.allSatisfy(\.isFinite) else { throw LUTError.invalid }
                if first == "DOMAIN_MIN" { guard !seenMin else { throw LUTError.invalid }; low = triplet; seenMin = true }
                else { guard !seenMax else { throw LUTError.invalid }; high = triplet; seenMax = true }
                continue
            }
            guard let n = dimension, fields.count == 3, values.count < n*n*n*4 else { throw LUTError.invalid }
            let triplet = fields.compactMap { Float($0) }
            guard triplet.count == 3, triplet.allSatisfy({ $0.isFinite && abs($0) <= 64 }) else { throw LUTError.invalid }
            started = true; values.append(contentsOf:triplet); values.append(1)
        }
        guard let n = dimension, values.count == n*n*n*4 else { throw LUTError.invalid }
        return try values.withUnsafeBytes { try LUTAsset(name:title,dimension:n,domainMin:low,domainMax:high,cube:Data($0)) }
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
        let graded = encoded.applyingFilter("CIColorCube",parameters:["inputCubeDimension":dimension,"inputCubeData":cube]).applyingFilter("CISRGBToneCurveToLinear")
        if amount >= 1 { return graded }
        return image.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:graded,kCIInputTimeKey:amount])
    }
}
enum LUTError: LocalizedError {
    case invalid, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: "Choose a valid display-sRGB 3D .cube LUT (2–65 points per side). 1D shapers, combined tables and Log/HDR conversion LUTs are not supported."
        case .tooLarge: "This LUT is too large. Choose a .cube file under 20 MB, up to 65 points per side."
        }
    }
}
