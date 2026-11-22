//
//  DSHSystemInfo.m
//

#import "DSHSystemInfo.h"

#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>
#import <sys/mount.h>      // statfs() 在 iOS SDK 里挂在 sys/mount.h，没有 sys/statfs.h
#include <stdlib.h>
#include <string.h>

// iOS SDK 沒有隨 libproc.h 一起出貨（那是 macOS 的私有頭），
// 所以這裡自己宣告要用到的三個函式與 proc_taskinfo 結構。
// 這些符號在 libSystem 裡一直存在，只是頭文件沒公開。
extern int proc_listallpids(void *buffer, int buffersize);
extern int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int buffersize);
extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);

#define DSH_PROC_PIDTASKINFO        4
#define DSH_PROC_PIDPATHINFO_MAXSIZE 4096

struct dsh_proc_taskinfo {
    uint64_t pti_virtual_size;
    uint64_t pti_resident_size;      // ← 就是任務管理器裡的「記憶體」
    uint64_t pti_total_user;
    uint64_t pti_total_system;
    uint64_t pti_threads_user;
    uint64_t pti_threads_system;
    int32_t  pti_policy;
    int32_t  pti_faults;
    int32_t  pti_pageins;
    int32_t  pti_cow_faults;
    int32_t  pti_messages_sent;
    int32_t  pti_messages_received;
    int32_t  pti_syscalls_mach;
    int32_t  pti_syscalls_unix;
    int32_t  pti_csw;
    int32_t  pti_threadnum;
    int32_t  pti_numrunning;
    int32_t  pti_priority;
};

@implementation DSHProcessInfo

- (NSString *)description {
    return [NSString stringWithFormat:@"<DSHProcessInfo %@ pid=%d rss=%llu>",
            self.name, self.pid, self.residentBytes];
}

@end

@implementation DSHSystemInfo

#pragma mark - 記憶體

+ (unsigned long long)totalMemory {
    int64_t mem = 0;
    size_t len = sizeof(mem);
    if (sysctlbyname("hw.memsize", &mem, &len, NULL, 0) != 0 || mem <= 0) {
        // 退路：用實體頁數 × 頁大小估算。
        return (unsigned long long)NSProcessInfo.processInfo.physicalMemory;
    }
    return (unsigned long long)mem;
}

/// 取一次 VM 統計。失敗回 NO。
static BOOL DSHFetchVM(vm_statistics64_data_t *out) {
    mach_port_t host = mach_host_self();
    if (host == MACH_PORT_NULL) return NO;

    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    kern_return_t kr = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)out, &count);
    mach_port_deallocate(mach_task_self(), host);
    return kr == KERN_SUCCESS;
}

+ (unsigned long long)usedMemory {
    vm_statistics64_data_t vm;
    if (!DSHFetchVM(&vm)) return 0;

    // active + wired + 壓縮器佔用，這個組合最接近「任務管理器」的口徑。
    unsigned long long pages = (unsigned long long)vm.active_count
                             + (unsigned long long)vm.wire_count
                             + (unsigned long long)vm.compressor_page_count;
    return pages * (unsigned long long)vm_kernel_page_size;
}

+ (unsigned long long)freeMemory {
    vm_statistics64_data_t vm;
    if (!DSHFetchVM(&vm)) return 0;
    return (unsigned long long)vm.free_count * (unsigned long long)vm_kernel_page_size;
}

+ (unsigned long long)reclaimableMemory {
    vm_statistics64_data_t vm;
    if (!DSHFetchVM(&vm)) return 0;
    unsigned long long pages = (unsigned long long)vm.inactive_count
                             + (unsigned long long)vm.purgeable_count;
    return pages * (unsigned long long)vm_kernel_page_size;
}

+ (NSInteger)memoryPressure {
    int level = 0;
    size_t len = sizeof(level);
    if (sysctlbyname("kern.memorystatus_level", &level, &len, NULL, 0) != 0) {
        return -1;
    }
    if (level < 0) level = 0;
    if (level > 100) level = 100;
    // kern.memorystatus_level 是「剩餘百分比」，換成「壓力」（越高越緊張）。
    return (NSInteger)(100 - level);
}

#pragma mark - 磁碟

+ (unsigned long long)diskTotal {
    struct statfs fs;
    if (statfs("/", &fs) != 0) return 0;
    return (unsigned long long)fs.f_blocks * (unsigned long long)fs.f_bsize;
}

+ (unsigned long long)diskFree {
    struct statfs fs;
    if (statfs("/", &fs) != 0) return 0;
    return (unsigned long long)fs.f_bavail * (unsigned long long)fs.f_bsize;
}

#pragma mark - 機型

+ (nullable NSString *)machineName {
    size_t len = 0;
    if (sysctlbyname("hw.machine", NULL, &len, NULL, 0) != 0 || len == 0) return nil;
    char *buf = malloc(len + 1);
    if (!buf) return nil;
    NSString *out = nil;
    if (sysctlbyname("hw.machine", buf, &len, NULL, 0) == 0) {
        buf[len] = '\0';
        out = [NSString stringWithUTF8String:buf];
    }
    free(buf);
    return out;
}

+ (NSInteger)cpuCount {
    int n = 0;
    size_t len = sizeof(n);
    if (sysctlbyname("hw.ncpu", &n, &len, NULL, 0) != 0 || n <= 0) {
        return NSProcessInfo.processInfo.processorCount;
    }
    return (NSInteger)n;
}

+ (NSString *)systemVersion {
    return [NSString stringWithFormat:@"%@ (%@)",
            UIDevice.currentDevice.systemVersion,
            UIDevice.currentDevice.model];
}

#pragma mark - 處理程序

+ (NSArray<DSHProcessInfo *> *)topProcesses:(NSUInteger)limit {
    int capacity = proc_listallpids(NULL, 0);
    if (capacity <= 0) return @[];

    capacity += 64;   // 留點餘裕，避免兩次呼叫之間又冒出幾個新進程。
    int *pids = calloc((size_t)capacity, sizeof(int));
    if (!pids) return @[];

    int count = proc_listallpids(pids, capacity * (int)sizeof(int));
    if (count <= 0) {
        free(pids);
        return @[];
    }

    NSMutableArray<DSHProcessInfo *> *out = [NSMutableArray arrayWithCapacity:(NSUInteger)count];

    for (int i = 0; i < count; i++) {
        pid_t pid = (pid_t)pids[i];
        if (pid <= 0) continue;

        DSHProcessInfo *item = [DSHProcessInfo new];
        item.pid = pid;

        // 名字：先試完整路徑的最後一段，失敗就退回 pid。
        char path[DSH_PROC_PIDPATHINFO_MAXSIZE] = {0};
        if (proc_pidpath(pid, path, sizeof(path)) > 0 && path[0] != '\0') {
            item.name = [[NSString stringWithUTF8String:path] lastPathComponent];
        } else {
            item.name = [NSString stringWithFormat:@"pid %d", pid];
        }
        if (item.name.length == 0) {
            item.name = [NSString stringWithFormat:@"pid %d", pid];
        }

        struct dsh_proc_taskinfo info;
        memset(&info, 0, sizeof(info));
        int got = proc_pidinfo(pid, DSH_PROC_PIDTASKINFO, 0, &info, (int)sizeof(info));
        if (got == (int)sizeof(info)) {
            item.residentBytes = (unsigned long long)info.pti_resident_size;
            item.readable = YES;
        } else {
            // 沒有權限讀別人家的 task info —— 照實標記，不假裝是 0。
            item.residentBytes = 0;
            item.readable = NO;
        }

        [out addObject:item];
    }

    free(pids);

    [out sortUsingComparator:^NSComparisonResult(DSHProcessInfo *a, DSHProcessInfo *b) {
        if (a.residentBytes == b.residentBytes) {
            return [a.name localizedStandardCompare:b.name];
        }
        // 大的排前面。
        return a.residentBytes > b.residentBytes ? NSOrderedAscending : NSOrderedDescending;
    }];

    if (limit > 0 && out.count > limit) {
        return [out subarrayWithRange:NSMakeRange(0, limit)];
    }
    return out;
}

#pragma mark - 格式化

+ (NSString *)formatBytes:(unsigned long long)bytes {
    const double kb = 1024.0;
    const double mb = kb * 1024.0;
    const double gb = mb * 1024.0;

    double v = (double)bytes;
    if (v >= gb)   return [NSString stringWithFormat:@"%.2f GB", v / gb];
    if (v >= mb)   return [NSString stringWithFormat:@"%.0f MB", v / mb];
    if (v >= kb)   return [NSString stringWithFormat:@"%.0f KB", v / kb];
    return [NSString stringWithFormat:@"%llu B", bytes];
}

@end
