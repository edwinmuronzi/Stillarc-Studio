import Foundation

struct ProjectOrganization:Codable,Equatable,Sendable {
    var favorite = false
    var rating = 0
    private enum CodingKeys:String,CodingKey { case favorite,rating }
    init(favorite:Bool = false,rating:Int = 0) { self.favorite = favorite;self.rating = min(5,max(0,rating)) }
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        favorite = try c.decodeIfPresent(Bool.self,forKey:.favorite) ?? false
        rating = min(5,max(0,try c.decodeIfPresent(Int.self,forKey:.rating) ?? 0))
    }
}
enum LibraryFilter:String,CaseIterable,Identifiable {
    case all = "All media",favorites = "Favorites",photos = "Photos",videos = "Videos",raw = "RAW",topRated = "4–5 stars"
    var id:String { rawValue }
}
enum LibrarySort:String,CaseIterable,Identifiable {
    case edited = "Recently edited",newest = "Newest imported",oldest = "Oldest imported",name = "Name",rating = "Highest rated"
    var id:String { rawValue }
}
enum LibraryQuery {
    static func projects(_ source:[Project],query:String,filter:LibraryFilter,sort:LibrarySort) -> [Project] {
        let text = query.trimmingCharacters(in:.whitespacesAndNewlines)
        return source.filter { p in
            guard text.isEmpty || p.name.localizedStandardContains(text) else { return false }
            switch filter {
            case .all:return true
            case .favorites:return p.organization?.favorite == true
            case .photos:return !p.isVideo
            case .videos:return p.isVideo
            case .raw:return p.isRAW
            case .topRated:return (p.organization?.rating ?? 0)>=4
            }
        }.sorted { a,b in
            switch sort {
            case .edited:if a.modified != b.modified { return a.modified>b.modified }
            case .newest:if a.created != b.created { return a.created>b.created }
            case .oldest:if a.created != b.created { return a.created<b.created }
            case .name:let order = a.name.localizedStandardCompare(b.name);if order != .orderedSame { return order == .orderedAscending }
            case .rating:let x = a.organization?.rating ?? 0,y = b.organization?.rating ?? 0;if x != y { return x>y }
            }
            return a.id.uuidString<b.id.uuidString
        }
    }
}
