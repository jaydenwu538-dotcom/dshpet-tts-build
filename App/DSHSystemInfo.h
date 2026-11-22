//
//  DSHSystemInfo.h
//  DSHPet 安裝器
//
//  讀取本機的記憶體 / 磁碟 / 處理程序資訊，供「系統狀態」頁顯示。
//  全部走公開 API（sysctl、host_statistics64、statfs、libproc），不 hook 任何東西。
//
//  已知限制：iOS 沒有全域處理程序樹的概念。proc_listallpids 能列出所有 pid，
//  但讀別人家的常駐記憶體要靠 proc_pidinfo(PROC_PIDTASKINFO)，沒有相應權限時
//  會直接失敗。所以清單裡會有一部分顯示「不可讀」——這是系統限制，不是 bug。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 單一處理程序的記憶體佔用。
@interface DSHProcessInfo : NSObject

@property (nonatomic) pid_t pid;
/// 可執行檔的最後一段路徑；拿不到時是 "pid 1234"。
@property (nonatomic, copy) NSString *name;
/// 常駐記憶體（RSS）。不可讀時為 0。
@property (nonatomic) unsigned long long residentBytes;
/// NO 表示 proc_pidinfo 被權限擋掉了。
@property (nonatomic) BOOL readable;

@end

@interface DSHSystemInfo : NSObject

/// hw.memsize，例如 4 GB 的機器回 4294967296。
+ (unsigned long long)totalMemory;
/// active + wired + compressed，接近「工作管理員」的已使用。
+ (unsigned long long)usedMemory;
/// 完全空閒的頁面。
+ (unsigned long long)freeMemory;
/// inactive + purgeable，系統需要時可以回收。
+ (unsigned long long)reclaimableMemory;

/// 0–100 的記憶體壓力；取不到時回 -1。
/// 這是 Jetsam 判斷要不要殺東西的依據，越低越健康。
+ (NSInteger)memoryPressure;

+ (unsigned long long)diskTotal;
+ (unsigned long long)diskFree;

/// 例如 "iPhone11,6"。
+ (nullable NSString *)machineName;
+ (NSInteger)cpuCount;
/// 例如 "16.6.1"。
+ (NSString *)systemVersion;

/// 依常駐記憶體降序取前 limit 個。
+ (NSArray<DSHProcessInfo *> *)topProcesses:(NSUInteger)limit;

/// 把位元組格式化成 "1.23 GB"。
+ (NSString *)formatBytes:(unsigned long long)bytes;

@end

NS_ASSUME_NONNULL_END
