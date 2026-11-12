#if DEBUG
import CoreImage
import Foundation

enum LogVerification {
    static func run() throws -> [String:Any] {
        func require(_ value:Bool,_ message:String) throws { if !value { throw NSError(domain:"LogVerification",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        try LogConversion.prepare()
        let context = ImageEngine.context()
        func pixel(_ image:CIImage) -> [Float] { var values = [Float](repeating:0,count:4);context.render(image,toBitmap:&values,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return values }
        func signal(_ rgb:[Double],alpha:Double = 1) -> CIImage { CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:0,width:4,height:4)) }
        try require(abs(LogConversion.decode(0.48827245852686763)-0.18)<0.000001,"Apple Log middle-gray reference failed")
        try require(abs(LogConversion.encode(0)-0.15047645230091253)<0.000000001 && abs(LogConversion.decode(LogConversion.encode(0)))<0.000001,"Black reference failed")
        try require(abs(LogConversion.decode(420.0/1023,profile:.sonySLog3Cine)-0.18)<0.000001,"Sony middle-gray reference")
        try require(abs(LogConversion.encode(0,profile:.sonySLog3Cine)-95.0/1023)<0.000001,"Sony black reference")
        try require(abs(LogConversion.decode(0.125,profile:.panasonicVLog))<0.000001 && abs(LogConversion.encode(0.18,profile:.panasonicVLog)-0.4233114488)<0.000001,"Panasonic published reference")
        var vectors = 0
        for profile in [CameraLogProfile.appleLog,.appleLog2,.sonySLog3Cine,.panasonicVLog] {
            for linear in [-0.04,0,0.001,0.01,0.18,1,4,12] {
                let code = LogConversion.encode(linear,profile:profile)
                try require(abs(LogConversion.decode(code,profile:profile)-linear)<0.000001,"Inverse transfer roundtrip failed")
                let output = pixel(LogConversion.apply(signal([code,code,code]),input:InputConversion(profile:profile,softHighlights:false)))
                try require((0..<3).allSatisfy { abs(Double(output[$0])-linear)<max(0.0001,abs(linear)*0.0001) },"GPU Log curve differs from reference")
                vectors += 1
            }
            let values = [0.23,0.18,0.12],codes = values.map { LogConversion.encode($0,profile:profile) }
            let output = pixel(LogConversion.apply(signal(codes),input:InputConversion(profile:profile,softHighlights:false)))
            let wanted = profile.matrix.map { zip($0,values).map(*).reduce(0,+) }
            try require((0..<3).allSatisfy { abs(Double(output[$0])-wanted[$0])<0.0001 },"Log gamut conversion differs from derived matrix")
            let half = pixel(LogConversion.apply(signal(codes,alpha:0.4),input:InputConversion(profile:profile,exposure:-1,softHighlights:false)))
            try require(abs(half[3]-0.4)<0.0001 && (0..<3).allSatisfy { abs(Double(half[$0])-wanted[$0]*0.2)<0.0001 },"Log exposure or alpha preservation failed")
            let bright = pixel(LogConversion.apply(signal([LogConversion.encode(12,profile:profile),LogConversion.encode(12,profile:profile),LogConversion.encode(12,profile:profile)]),input:InputConversion(profile:profile)))
            try require((0..<3).allSatisfy { bright[$0]>0.99 && bright[$0]<=1.0001 },"SDR shoulder did not contain bright highlights")
        }
        let source = signal([0.2,0.4,0.6])
        try require(LogConversion.apply(source,input:InputConversion()) === source,"Standard input did not bypass conversion")
        var recipe = Recipe();recipe.input = InputConversion(profile:.appleLog2,exposure:-0.5);recipe.lut = try LUTVerification.example()
        let decoded = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe))
        try require(decoded == recipe,"Input conversion did not persist")
        try require(recipe.colorPreset.input == InputConversion() && recipe.colorPreset.lut == recipe.lut,"Creative preset leaked input conversion")
        let legacy = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8))
        try require(legacy.input == InputConversion(),"Legacy source defaults changed")
        var input = InputConversion(profile:.appleLog,exposure:.infinity)
        input = input.validated();try require(input.exposure == 0,"Input exposure validation failed")
        return ["passed":true,"curveVectors":vectors,"bothGamuts":true,"exposureAlpha":true,"highlightShoulder":true,"standardBypass":true,"persistence":true,"presetInputIsolation":true]
    }
}
#endif
