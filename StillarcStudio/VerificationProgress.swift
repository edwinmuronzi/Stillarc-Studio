#if DEBUG
import Foundation

enum VerificationProgress {
    static func record(_ stage:String) {
        let data:[String:Any] = ["stage":stage,"thermal":ProcessInfo.processInfo.thermalState.rawValue,"time":Date().timeIntervalSince1970,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"]
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("verification-progress.json")
        if let encoded = try? JSONSerialization.data(withJSONObject:data) { try? encoded.write(to:url,options:.atomic) }
        print("Studio verification: \(stage), thermal \(ProcessInfo.processInfo.thermalState.rawValue)")
    }
}
#endif
