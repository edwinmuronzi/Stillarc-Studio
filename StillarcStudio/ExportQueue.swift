import Foundation
import Observation
import UIKit

enum QueueJobState:String,Codable,Sendable {case waiting,running,completed,failed,cancelled}
struct QueueJob:Identifiable,Codable,Sendable {
    var id=UUID()
    var created=Date()
    var projects:[Project]
    var format:ExportFormat
    var privacy:ExportPrivacy
    var delivery:DeliverySettings
    var tenBit=true
    var state=QueueJobState.waiting
    var files:[String]=[]
    var failures:[String]=[]
    var title:String {projects.count==1 ? projects[0].name : "\(projects.count) items"}
}
actor ExportQueueStore {
    let root:URL
    init(root:URL){self.root=root}
    private struct Record:Codable {var schema=7;var jobs:[QueueJob]}
    func load() throws ->[QueueJob] {
        let index=root.appendingPathComponent("queue.json")
        guard FileManager.default.fileExists(atPath:index.path) else{return []}
        guard (try index.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=67_108_864 else {throw ProjectArchive.fail("The saved queue is too large to open.")}
        let record=try JSONDecoder().decode(Record.self,from:Data(contentsOf:index))
        guard (1...7).contains(record.schema),record.jobs.count<=10,Set(record.jobs.map(\.id)).count==record.jobs.count,record.jobs.allSatisfy({!$0.projects.isEmpty && $0.projects.count<=20 && $0.files.allSatisfy(ProjectArchive.flat)}) else {throw ProjectArchive.fail("The saved queue format is unsupported. Its files have been kept.")}
        return record.jobs.map {job in var j=job;if j.state == .running {j.state = .waiting};if j.state == .completed && !j.files.allSatisfy({FileManager.default.fileExists(atPath:output(j.id,$0).path)}) {j.state = .failed;j.files=[];j.failures=["An export file is missing. Retry from the saved source edits."]};return j}
    }
    func save(_ jobs:[QueueJob]) throws {
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let data=try JSONEncoder().encode(Record(jobs:jobs));guard data.count<=67_108_864 else {throw ProjectArchive.fail("This queue is too large. Remove a finished job before adding more.")}
        try data.write(to:root.appendingPathComponent("queue.json"),options:.atomic)
    }
    func output(_ id:UUID,_ file:String)->URL {root.appendingPathComponent(id.uuidString).appendingPathComponent(file)}
    func keep(_ result:BatchExportResult,id:UUID) throws ->[String] {
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let target=root.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath:target.path) {try FileManager.default.removeItem(at:target)}
        try FileManager.default.moveItem(at:result.folder,to:target)
        return result.urls.map(\.lastPathComponent)
    }
    func removeFiles(_ id:UUID) throws {let folder=root.appendingPathComponent(id.uuidString);if FileManager.default.fileExists(atPath:folder.path){try FileManager.default.removeItem(at:folder)}}
}
@MainActor @Observable final class StudioExportQueue {
    private(set) var jobs:[QueueJob]=[]
    private(set) var running=false
    private(set) var pausing=false
    private(set) var progress=0.0
    private(set) var status=""
    private(set) var loaded=false
    var error:String?
    private var loadingTask:Task<Void,Never>?
    private var blocked=false
    private var requested=false
    private var worker:Task<Void,Never>?
    let vault:ProjectVault
    let store:ExportQueueStore
    init(vault:ProjectVault,root:URL?=nil){self.vault=vault;store=ExportQueueStore(root:root ?? vault.root.deletingLastPathComponent().appendingPathComponent("StudioDeliveryQueue"))}
    var pending:Int {jobs.filter {$0.state == .waiting}.count}
    func load() async {
        if let loadingTask {await loadingTask.value;return}
        guard !loaded else{return}
        let loading=Task {@MainActor in
            do {jobs=try await store.load();loaded=true;try await persist()} catch {loaded=true;blocked=true;self.error=error.localizedDescription}
        }
        loadingTask=loading;await loading.value;loadingTask=nil
    }
    private func persist() async throws {try await store.save(jobs)}
    @discardableResult func enqueue(_ projects:[Project],format:ExportFormat,privacy:ExportPrivacy,delivery:DeliverySettings,tenBit:Bool=true) async ->Bool {
        if !loaded {await load()}
        guard !blocked,jobs.count<10,!projects.isEmpty,projects.count<=20 else {error="Queue up to 10 deliveries, with up to 20 items each. Remove finished jobs to make room.";return false}
        error=nil
        let job=QueueJob(projects:projects,format:format,privacy:privacy,delivery:delivery,tenBit:tenBit)
        jobs.append(job)
        do {try await persist();return true} catch {jobs.removeAll {$0.id==job.id};self.error=error.localizedDescription;return false}
    }
    func start() {
        guard loaded,!blocked,!running,worker==nil,pending>0 else{return}
        error=nil;requested=true;running=true;pausing=false
        worker=Task {await run()}
    }
    func pause(){guard running else{return};requested=false;pausing=true;worker?.cancel()}
    func waitUntilIdle() async {await worker?.value}
    func cancel(_ id:UUID) async {
        guard let index=jobs.firstIndex(where:{$0.id==id}) else{return}
        let wasRunning=jobs[index].state == .running
        guard wasRunning || jobs[index].state == .waiting else{return}
        jobs[index].state = .cancelled
        if wasRunning {pause()}
        do {try await persist()} catch {self.error=error.localizedDescription}
    }
    func retry(_ id:UUID) async {
        guard !running,let i=jobs.firstIndex(where:{$0.id==id}),jobs[i].state == .failed || jobs[i].state == .cancelled else{return}
        jobs[i].state = .waiting;jobs[i].failures=[]
        do {try await persist()} catch {self.error=error.localizedDescription}
    }
    func move(_ id:UUID,by delta:Int) async {
        guard !running,let i=jobs.firstIndex(where:{$0.id==id}),jobs.indices.contains(i+delta) else{return}
        jobs.swapAt(i,i+delta);do {try await persist()} catch {jobs.swapAt(i,i+delta);self.error=error.localizedDescription}
    }
    func remove(_ id:UUID) async {
        guard !running,let i=jobs.firstIndex(where:{$0.id==id}) else{return}
        let old=jobs.remove(at:i)
        do {try await persist()} catch {jobs.insert(old,at:min(i,jobs.count));self.error=error.localizedDescription;return}
        do {try await store.removeFiles(id)} catch {self.error=error.localizedDescription}
    }
    func urls(_ job:QueueJob)->[URL] {job.files.map {store.root.appendingPathComponent(job.id.uuidString).appendingPathComponent($0)}}
    private func run() async {
        let idle=UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled=true
        defer {running=false;pausing=false;requested=false;worker=nil;progress=0;UIApplication.shared.isIdleTimerDisabled=idle}
        while requested,!Task.isCancelled,let snapshot=jobs.first(where:{$0.state == .waiting}) {
            let id=snapshot.id
            guard let i=jobs.firstIndex(where:{$0.id==id}) else{break};jobs[i].state = .running;progress=0;status="Preparing delivery"
            do {
                try await persist();try Task.checkCancellation()
                let vault=vault
                let render=Task.detached(priority:.utility) {
                    try await BatchExportEngine.run(snapshot.projects,vault:vault,format:snapshot.format,privacy:snapshot.privacy,delivery:snapshot.delivery,tenBit:snapshot.tenBit) {index,fraction,name in
                        await MainActor.run {if self.jobs.contains(where:{$0.id==id && $0.state == .running}) {self.progress=(Double(index)+fraction)/Double(snapshot.projects.count);self.status="\(index+1) of \(snapshot.projects.count) · "+name}}
                    }
                }
                let result=try await withTaskCancellationHandler(operation:{try await render.value},onCancel:{render.cancel()})
                if Task.isCancelled {await Task.detached(priority:.utility){try? FileManager.default.removeItem(at:result.folder)}.value;throw CancellationError()}
                let files=try await store.keep(result,id:id)
                guard let index=jobs.firstIndex(where:{$0.id==id}) else{break}
                jobs[index].files=files;jobs[index].failures=result.failures;jobs[index].state=files.isEmpty ? .failed:.completed
                try await persist()
            } catch is CancellationError {
                if let index=jobs.firstIndex(where:{$0.id==id}),jobs[index].state == .running {jobs[index].state = .waiting}
                try? await persist();break
            } catch {
                if let index=jobs.firstIndex(where:{$0.id==id}) {jobs[index].state = .failed;jobs[index].failures=[error.localizedDescription]}
                try? await persist()
            }
        }
    }
}
