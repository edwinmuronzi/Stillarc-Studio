import Foundation

struct LookOrganization:Codable,Equatable,Sendable {
    var favorite=false
    var collection:String? = nil
    static func clean(_ value:String)->String {String(value.unicodeScalars.filter {!CharacterSet.controlCharacters.contains($0)}.map(String.init).joined().trimmingCharacters(in:.whitespacesAndNewlines).prefix(48))}
}
enum LookSort:String,CaseIterable,Identifiable {case manual="Library order",name="Name",recent="Reverse order";var id:String {rawValue}}
enum LookQuery {
    static func collections(_ looks:[SavedLook])->[String] {Array(Set(looks.compactMap {$0.organization?.collection}.filter {!$0.isEmpty})).sorted {$0.localizedStandardCompare($1) == .orderedAscending}}
    static func filtered(_ looks:[SavedLook],text:String,favorites:Bool,collection:String?,sort:LookSort)->[SavedLook] {
        let q=text.trimmingCharacters(in:.whitespacesAndNewlines)
        let result=looks.filter {look in (!favorites || look.organization?.favorite == true) && (collection==nil || look.organization?.collection==collection) && (q.isEmpty || look.name.localizedStandardContains(q) || look.organization?.collection?.localizedStandardContains(q)==true)}
        switch sort {case .manual:return result;case .recent:return result.reversed();case .name:return result.sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending}}
    }
}
struct LookLibraryEntry:Codable,Sendable {
    var id:UUID
    var preset:PresetDocument
    var organization:LookOrganization?
}
struct LookLibraryPackage:Codable,Sendable {
    var format="StillarcLooks"
    var schema=1
    var minimumReader=49
    var part=1
    var totalParts=1
    var entries:[LookLibraryEntry]
    func validated() throws ->[SavedLook] {
        guard format=="StillarcLooks",schema==1,minimumReader<=49,minimumReader>=43,part>=1,totalParts>=part,totalParts<=2048,!entries.isEmpty,entries.count<=64,Set(entries.map(\.id)).count==entries.count else {throw LookLibraryArchive.fail("This look library version is unsupported or damaged.")}
        return try entries.map {entry in
            let p=entry.preset,name=p.name.trimmingCharacters(in:.whitespacesAndNewlines)
            guard (1...7).contains(p.schema),!name.isEmpty,name.utf8.count<=400,p.recipe==p.recipe.colorPreset else {throw LookLibraryArchive.fail("A preset contains unsupported or source-specific edits.")}
            var org=entry.organization
            if let collection=org?.collection {guard collection==LookOrganization.clean(collection),!collection.isEmpty else {throw LookLibraryArchive.fail("A collection name is invalid.")}}
            if org?.favorite != true && org?.collection == nil {org=nil}
            return SavedLook(id:entry.id,name:name,recipe:p.recipe.validated().colorPreset,organization:org)
        }
    }
}
enum LookLibraryArchive {
    static let maxBytes=32*1024*1024
    static func fail(_ text:String)->NSError {NSError(domain:"LookLibrary",code:1,userInfo:[NSLocalizedDescriptionKey:text])}
    static func read(_ url:URL) throws ->[SavedLook] {
        let access=url.startAccessingSecurityScopedResource();defer {if access {url.stopAccessingSecurityScopedResource()}}
        try Task.checkCancellation()
        let size=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey]);guard size.isRegularFile==true,let bytes=size.fileSize,bytes>0,bytes<=maxBytes else {throw fail("Choose a Stillarc .studiolooks file of 32 MB or less.")}
        let package=try JSONDecoder().decode(LookLibraryPackage.self,from:Data(contentsOf:url))
        try Task.checkCancellation();return try package.validated()
    }
    static func write(_ looks:[SavedLook],progress:@Sendable(Double)->Void={_ in}) throws ->[URL] {
        guard !looks.isEmpty else {throw fail("Select at least one saved look.")}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("StudioLookLibrary-\(UUID())")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var success=false;defer {if !success {try? FileManager.default.removeItem(at:folder)}}
        guard Set(looks.map(\.id)).count==looks.count else {throw fail("Duplicate look identifiers. Your saved library is unchanged.")}
        var groups=[[LookLibraryEntry]](),entries=[LookLibraryEntry](),bytes=1024
        for (i,look) in looks.enumerated() {
            try Task.checkCancellation()
            let entry=LookLibraryEntry(id:look.id,preset:PresetDocument(name:String(look.name.prefix(100)),recipe:look.recipe.colorPreset),organization:look.organization)
            let size=try autoreleasepool {try JSONEncoder().encode(entry).count}
            guard size<maxBytes-1024 else {throw fail("One preset is too large to package.")}
            if entries.count==64 || bytes+size+2>maxBytes {groups.append(entries);entries=[];bytes=1024}
            entries.append(entry);bytes+=size+2;if i % max(1,looks.count/100)==0 || i+1==looks.count {progress(0.5*Double(i+1)/Double(looks.count))}
        }
        if !entries.isEmpty {groups.append(entries)}
        var urls=[URL]()
        for (i,group) in groups.enumerated() {
            try Task.checkCancellation()
            let url=folder.appendingPathComponent(String(format:"Stillarc-Looks-%03d-of-%03d.studiolooks",i+1,groups.count))
            try autoreleasepool {
                let data=try JSONEncoder().encode(LookLibraryPackage(part:i+1,totalParts:groups.count,entries:group))
                guard data.count<=maxBytes else {throw fail("This look library part is too large.")}
                try data.write(to:url,options:.atomic)
            }
            urls.append(url);progress(0.5+0.5*Double(i+1)/Double(groups.count))
        }
        try Task.checkCancellation();success=true;return urls
    }
}
extension StudioLibrary {
    @discardableResult func updateLookOrganization(_ id:UUID,favorite:Bool?=nil,collection:String?=nil,setCollection:Bool=false) async ->Bool {
        guard !looksBusy,let i=looks.firstIndex(where:{$0.id==id}) else {return false}
        looksBusy=true;defer {looksBusy=false}
        var updated=looks,org=updated[i].organization ?? LookOrganization()
        if let favorite {org.favorite=favorite}
        if setCollection {let value=LookOrganization.clean(collection ?? "");org.collection=value.isEmpty ? nil:value}
        updated[i].organization=org.favorite || org.collection != nil ? org:nil
        do {try await vault.saveLookMetadata(updated);looks=updated;return true} catch {self.error=error.localizedDescription;return false}
    }
    @discardableResult func moveLook(_ id:UUID,by offset:Int) async ->Bool {
        guard !looksBusy,let i=looks.firstIndex(where:{$0.id==id}),looks.indices.contains(i+offset) else {return false}
        looksBusy=true;defer {looksBusy=false};var updated=looks;updated.swapAt(i,i+offset)
        do {try await vault.saveLookMetadata(updated);looks=updated;return true} catch {self.error=error.localizedDescription;return false}
    }
    func importLookLibrary(_ imported:[SavedLook]) async throws ->(added:Int,skipped:Int) {
        guard !looksBusy else {throw LookLibraryArchive.fail("Wait for the current library change to finish.")}
        looksBusy=true;defer {looksBusy=false}
        var updated=looks,added=0,skipped=0
        for item in imported {
            try Task.checkCancellation()
            if updated.contains(where:{$0.name==item.name && $0.recipe==item.recipe && $0.organization==item.organization}) {skipped+=1;continue}
            var copy=item;copy.id=UUID();updated.append(copy);added+=1
        }
        guard updated.count<=2048 else {throw LookLibraryArchive.fail("This import would exceed 2,048 saved looks. Your library is unchanged.")}
        try Task.checkCancellation()
        if added>0 {try await vault.saveLooks(updated);looks=updated}
        return (added,skipped)
    }
}

private struct LookMetadataEntry:Codable {var id:UUID;var organization:LookOrganization?}
private struct LookMetadataRecord:Codable {var schema=1;var entries:[LookMetadataEntry]}
extension ProjectVault {
    private var lookMetadataURL:URL {root.appendingPathComponent("look-library").appendingPathComponent("organization.json")}
    func saveLookMetadata(_ looks:[SavedLook]) throws {
        try Task.checkCancellation()
        let record=LookMetadataRecord(entries:looks.map {LookMetadataEntry(id:$0.id,organization:$0.organization)})
        guard record.entries.count<=2048,Set(record.entries.map(\.id)).count==record.entries.count else {throw LookLibraryArchive.fail("This look library is too large to organize.")}
        let data=try JSONEncoder().encode(record)
        try FileManager.default.createDirectory(at:lookMetadataURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:recoveryRoot,withIntermediateDirectories:true)
        try data.write(to:recoveryRoot.appendingPathComponent("look-organization.json"),options:.atomic)
        try data.write(to:lookMetadataURL,options:.atomic)
    }
    func organizedLooks(_ looks:[SavedLook])->[SavedLook] {
        for url in [lookMetadataURL,recoveryRoot.appendingPathComponent("look-organization.json")] {
            guard let bytes=try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize,bytes<=1_048_576,let data=try? Data(contentsOf:url),let record=try? JSONDecoder().decode(LookMetadataRecord.self,from:data),record.schema==1,record.entries.count<=2048,Set(record.entries.map(\.id)).count==record.entries.count else {continue}
            var indexed=Dictionary(looks.map {($0.id,$0)},uniquingKeysWith:{a,_ in a}),result=[SavedLook]()
            for e in record.entries {if var look=indexed.removeValue(forKey:e.id) {look.organization=e.organization;result.append(look)}}
            result.append(contentsOf:looks.filter {indexed[$0.id] != nil});return result
        }
        return looks
    }
}
