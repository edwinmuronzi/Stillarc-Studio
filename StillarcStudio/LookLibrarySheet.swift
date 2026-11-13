import SwiftUI
import UniformTypeIdentifiers

struct LookLibrarySheet:View {
    @Bindable var library:StudioLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var query=""
    @State private var favorites=false
    @State private var collection:String?
    @State private var sort=LookSort.manual
    @State private var chosen=Set<UUID>()
    @State private var editing:SavedLook?
    @State private var editName=""
    @State private var collecting:SavedLook?
    @State private var collectionName=""
    @State private var importing=false
    @State private var committing=false
    @State private var busy=false
    @State private var progress=0.0
    @State private var message:String?
    @State private var error:String?
    @State private var urls=[URL]()
    @State private var exportJob:Task<[URL],Error>?
    @State private var importJob:Task<[SavedLook],Error>?
    private var visible:[SavedLook] {LookQuery.filtered(library.looks,text:query,favorites:favorites,collection:collection,sort:sort)}
    private var movingAllowed:Bool {sort == .manual && query.isEmpty && collection==nil && !favorites}
    var body:some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Menu {Button("All collections"){collection=nil};ForEach(LookQuery.collections(library.looks),id:\.self){name in Button(name){collection=name}}} label:{Label(collection ?? "All collections",systemImage:"folder")}.accessibilityIdentifier("lookCollectionFilter")
                        Spacer()
                        Button {favorites.toggle()} label:{Image(systemName:favorites ? "star.fill":"star")}.accessibilityLabel("Only favourite looks").accessibilityValue(favorites ? "On":"Off").accessibilityIdentifier("favoriteLooksFilter")
                    }
                    Picker("Sort",selection:$sort){ForEach(LookSort.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.menu)
                    HStack {Button("Select visible"){chosen.formUnion(visible.map(\.id))}.accessibilityIdentifier("selectVisibleLooks");Spacer();Button("Clear"){chosen=[]}.disabled(chosen.isEmpty);Text("\(chosen.count) selected").font(.caption.monospacedDigit())}
                } footer:{Text("Tap a row to choose looks for backup. The star marks favourites; the menu renames, groups or reorders a look. These changes never alter its grade.")}
                Section("Saved looks (\(visible.count))") {
                    if visible.isEmpty {Text(library.looks.isEmpty ? "Save a preset in an editor to start your library.":"No looks match these filters.").foregroundStyle(StudioStyle.secondary)}
                    ForEach(visible){look in
                        lookRow(look)
                    }
                }
                Section {
                    Button("Back up selected",systemImage:"externaldrive"){backup(all:false)}.disabled(chosen.isEmpty).accessibilityIdentifier("backupSelectedLooks")
                    Button("Back up all looks",systemImage:"externaldrive.badge.plus"){backup(all:true)}.disabled(library.looks.isEmpty).accessibilityIdentifier("backupAllLooks")
                    Button("Import look library",systemImage:"square.and.arrow.down"){importing=true}.accessibilityIdentifier("importLookLibrary")
                    if !urls.isEmpty {ShareLink(items:urls){Label("Save / share library (\(urls.count) \(urls.count==1 ? "part":"parts"))",systemImage:"square.and.arrow.up")}.accessibilityIdentifier("shareLookLibrary")}
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--look-library-ui-test"),let first=urls.first {Button("Import test backup"){restore(first)}.accessibilityIdentifier("importTestLookLibrary")}
                    #endif
                } header:{Text("Portable look library")} footer:{Text("Includes the saved grade, embedded LUT, favourite and collection. No photos, videos, masks, project edits or app settings. Large libraries split into numbered .studiolooks files; save every part and import them one at a time. Imports add copies, keep existing looks and skip exact duplicates. Nothing is uploaded automatically.")}
                if busy {Section {ProgressView(value:progress);Text("Preparing library…").font(.caption)}}
                if let message {Section {Text(message).font(.caption).foregroundStyle(StudioStyle.secondary)}}
                if let error {Section {Text(error).font(.caption).foregroundStyle(.orange)}}
            }.searchable(text:$query,prompt:"Search looks or collections").scrollContentBackground(.hidden).background(StudioStyle.ink).disabled(busy || library.looksBusy)
                .navigationTitle("Look library").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.topBarLeading) {Menu("Library") {
                        Button("Back up all looks"){backup(all:true)}.disabled(library.looks.isEmpty)
                        Button("Back up selected"){backup(all:false)}.disabled(chosen.isEmpty)
                        Button("Import look library"){importing=true}
                        if !urls.isEmpty {ShareLink(items:urls){Text("Save / share library")}}
                    }.disabled(busy || library.looksBusy)}
                    ToolbarItem(placement:.topBarTrailing){Button(busy ? "Cancel":"Done"){if busy {cancel()} else {dismiss()}}.disabled(committing).accessibilityIdentifier("closeLookLibrary")}
                }
                .alert("Rename look",isPresented:Binding(get:{editing != nil},set:{if !$0 {editing=nil}})) {
                    TextField("Look name",text:$editName)
                    Button("Cancel",role:.cancel){editing=nil}
                    Button("Save"){if let look=editing {Task {if !(await library.renameLook(look,name:editName)){error=library.error}}};editing=nil}.disabled(editName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
                .alert("New collection",isPresented:Binding(get:{collecting != nil},set:{if !$0 {collecting=nil}})) {
                    TextField("Collection name",text:$collectionName)
                    Button("Cancel",role:.cancel){collecting=nil}
                    Button("Save"){if let look=collecting {setCollection(look,collectionName)};collecting=nil}.disabled(LookOrganization.clean(collectionName).isEmpty)
                }
                .fileImporter(isPresented:$importing,allowedContentTypes:[.item]){result in switch result {case .success(let url):restore(url);case .failure(let failure):error=failure.localizedDescription}}
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
            .onChange(of:phase){_,value in if value != .active && busy && !committing {cancel()}}
            .onDisappear {exportJob?.cancel();importJob?.cancel();cleanup()}
    }
    private func lookRow(_ look:SavedLook)->some View {
                        HStack(spacing:8) {
                            Button {if !chosen.insert(look.id).inserted {chosen.remove(look.id)}} label:{
                                HStack {Image(systemName:chosen.contains(look.id) ? "checkmark.circle.fill":"circle").foregroundStyle(StudioStyle.blue)
                                    VStack(alignment:.leading,spacing:3){Text(look.name).foregroundStyle(.primary).lineLimit(2);if let c=look.organization?.collection {Text(c).font(.caption).foregroundStyle(StudioStyle.secondary)}}
                                }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Select look \(look.name)").accessibilityValue(chosen.contains(look.id) ? "Selected":"Not selected")
                            Button {toggleFavorite(look)} label:{Image(systemName:look.organization?.favorite == true ? "star.fill":"star").frame(width:36,height:44)}.buttonStyle(.borderless).accessibilityLabel("Favourite \(look.name)").accessibilityValue(look.organization?.favorite == true ? "On":"Off")
                            Menu {
                                Button("Rename"){editName=look.name;editing=look}
                                Menu("Collection") {
                                    Button("New collection…"){collectionName="";collecting=look}
                                    Button("No collection"){setCollection(look,nil)}
                                    ForEach(LookQuery.collections(library.looks),id:\.self){name in Button(name){setCollection(look,name)}}
                                }
                                Button("Duplicate"){Task {if !(await library.saveLook(name:look.name+" copy",recipe:look.recipe)){error=library.error}}}
                                Button("Move up"){move(look,-1)}.disabled(!movingAllowed || library.looks.first?.id==look.id)
                                Button("Move down"){move(look,1)}.disabled(!movingAllowed || library.looks.last?.id==look.id)
                                Button("Delete look",role:.destructive){Task {await library.removeLook(look);chosen.remove(look.id)}}
                            } label:{Image(systemName:"ellipsis.circle").frame(width:36,height:44)}.accessibilityLabel("Library options \(look.name)")
                        }
    }
    private func toggleFavorite(_ look:SavedLook){Task {if !(await library.updateLookOrganization(look.id,favorite:look.organization?.favorite != true)){error=library.error}}}
    private func setCollection(_ look:SavedLook,_ name:String?){Task {if !(await library.updateLookOrganization(look.id,collection:name,setCollection:true)){error=library.error}}}
    private func move(_ look:SavedLook,_ direction:Int){Task {if !(await library.moveLook(look.id,by:direction)){error=library.error}}}
    private func cleanup(){let old=urls;urls=[];Task.detached(priority:.utility){for folder in Set(old.map {$0.deletingLastPathComponent()}) where folder.lastPathComponent.hasPrefix("StudioLookLibrary-"){try? FileManager.default.removeItem(at:folder)}}}
    private func cancel(){exportJob?.cancel();importJob?.cancel();message="Canceled. Your saved looks are unchanged."}
    private func backup(all:Bool){
        guard !busy else {return};cleanup();busy=true;progress=0;error=nil;message=nil
        let snapshot=library.looks.filter {all || chosen.contains($0.id)}
        let task=Task.detached(priority:.utility){try LookLibraryArchive.write(snapshot){p in Task {@MainActor in progress=p}}};exportJob=task
        Task {@MainActor in defer {busy=false;exportJob=nil}
            do {let files=try await task.value;guard !task.isCancelled,phase == .active else {for folder in Set(files.map {$0.deletingLastPathComponent()}) {try? FileManager.default.removeItem(at:folder)};return};urls=files;message="Library ready. Use Save / share to keep all \(files.count) parts in Files."}
            catch is CancellationError {message="Canceled. Your saved looks are unchanged."} catch {self.error=error.localizedDescription}
        }
    }
    private func restore(_ url:URL){
        guard !busy else {return};busy=true;error=nil;message=nil
        let task=Task.detached(priority:.utility){try LookLibraryArchive.read(url)};importJob=task
        Task {@MainActor in defer {busy=false;importJob=nil}
            do {let saved=try await task.value;guard !task.isCancelled,phase == .active else {return};committing=true;defer {committing=false};let result=try await library.importLookLibrary(saved);message="Imported \(result.added) looks; skipped \(result.skipped) exact duplicates."}
            catch is CancellationError {message="Canceled. Your saved looks are unchanged."} catch {self.error=error.localizedDescription}
        }
    }
}
