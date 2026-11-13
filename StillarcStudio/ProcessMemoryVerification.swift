#if DEBUG
import Darwin

enum ProcessMemoryVerification {
    static func footprint()->UInt64 {
        var info=task_vm_info_data_t(),count=mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size/MemoryLayout<integer_t>.size)
        let capacity=Int(count)
        let status=withUnsafeMutablePointer(to:&info) {p in p.withMemoryRebound(to:integer_t.self,capacity:capacity) {task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&count)}}
        return status==KERN_SUCCESS ? info.phys_footprint:0
    }
}
#endif
