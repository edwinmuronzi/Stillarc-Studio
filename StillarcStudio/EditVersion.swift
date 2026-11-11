import Foundation

struct EditVersion:Identifiable,Codable,Equatable,Sendable {
    var id = UUID()
    var name:String
    var created = Date()
}
