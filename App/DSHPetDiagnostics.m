#import "DSHPetDiagnostics.h"
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <unistd.h>
#import <sys/utsname.h>
#import <sys/stat.h>
#import <stdlib.h>
#import <string.h>
#import "DSHPetToggle.h"

extern char **environ;

static NSString *const kDylibPath = @"/var/jb/Library/MobileSubstrate/DynamicLibraries/DSHPet.dylib";
static NSString *const kFilterPath = @"/var/jb/Library/MobileSubstrate/DynamicLibraries/DSHPet.plist";
static NSString *const kAssetsDir = @"/var/jb/Library/DSHPet/mov";
static NSString *const kHelperPath = @"/var/jb/usr/bin/dshpet-respring";

@implementation DSHStatusItem

+ (instancetype)title:(NSString *)title value:(NSString *)value note:(NSString *)note state:(DSHState)state {
    DSHStatusItem *item = [DSHStatusItem new];
    item.title = title;
    item.value = value;
    item.note = note;
    item.state = state;
    return item;
}

@end

static BOOL DSHPathExists(NSString *path) {
    return path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static long long DSHFileSize(NSString *path) {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    return [attrs[NSFileSize] longLongValue];
}

static NSString *DSHHumanSize(long long bytes) {
    if (bytes <= 0) return @"0 B";
    if (bytes >= 1024LL * 1024) return [NSString stringWithFormat:@"%.1f MB", bytes / 1024.0 / 1024.0];
    if (bytes >= 1024) return [NSString stringWithFormat:@"%.0f KB", bytes / 1024.0];
    return [NSString stringWithFormat:@"%lld B", bytes];
}

static BOOL DSHExecute(NSString *path, NSArray<NSString *> *args) {
    if (path.length == 0 || access(path.fileSystemRepresentation, X_OK) != 0) return NO;
    NSMutableArray<NSString *> *full = [NSMutableArray arrayWithObject:path];
    [full addObjectsFromArray:args];
    NSUInteger count = full.count;
    char **argv = calloc(count + 1, sizeof(char *));
    if (!argv) return NO;
    for (NSUInteger i = 0; i < count; i++) {
        argv[i] = strdup(full[i].fileSystemRepresentation);
    }
    argv[count] = NULL;
    pid_t pid = 0;
    int rc = posix_spawn(&pid, path.fileSystemRepresentation, NULL, NULL, argv, environ);
    for (NSUInteger i = 0; i < count; i++) free(argv[i]);
    free(argv);
    return rc == 0;
}

@implementation DSHPetDiagnostics

+ (BOOL)hasJailbreakAccess {
    return access("/var/jb", F_OK) == 0;
}

+ (NSInteger)installedAssetCount {
    NSArray<NSString *> *list = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kAssetsDir error:NULL];
    NSInteger count = 0;
    for (NSString *name in list) {
        if ([name.pathExtension.lowercaseString isEqualToString:@"mov"]) count++;
    }
    return count;
}

+ (NSArray<DSHStatusItem *> *)statusItems {
    NSMutableArray<DSHStatusItem *> *items = [NSMutableArray array];

    BOOL jb = [self hasJailbreakAccess];
    [items addObject:[DSHStatusItem title:@"越獄環境"
                                    value:jb ? @"/var/jb 可用" : @"無法讀取 /var/jb"
                                     note:jb ? nil : @"請確認 Dopamine 越獄已生效；本 App 需用 TrollStore 安裝才能無沙盒讀取系統目錄"
                                    state:jb ? DSHStateOK : DSHStateBad]];

    BOOL dylib = DSHPathExists(kDylibPath);
    [items addObject:[DSHStatusItem title:@"插件本體 DSHPet.dylib"
                                    value:dylib ? DSHHumanSize(DSHFileSize(kDylibPath)) : @"未安裝"
                                     note:dylib ? nil : @"尚未安裝桌寵插件，請先點「安裝 / 重裝桌寵」"
                                    state:dylib ? DSHStateOK : DSHStateBad]];

    BOOL filter = DSHPathExists(kFilterPath);
    [items addObject:[DSHStatusItem title:@"注入設定 DSHPet.plist"
                                    value:filter ? @"已就位" : @"缺失"
                                     note:filter ? nil : @"缺少 filter plist 時插件不會注入 SpringBoard"
                                    state:filter ? DSHStateOK : DSHStateBad]];

    NSInteger count = [self installedAssetCount];
    DSHState assetState = count >= 100 ? DSHStateOK : (count > 0 ? DSHStateWarn : DSHStateBad);
    [items addObject:[DSHStatusItem title:@"動畫素材"
                                    value:[NSString stringWithFormat:@"%ld 個 .mov", (long)count]
                                     note:count >= 100 ? nil : @"素材不完整時寵物會出現空白或不動"
                                    state:assetState]];

    BOOL helper = DSHPathExists(kHelperPath);
    [items addObject:[DSHStatusItem title:@"重啟助手"
                                    value:helper ? @"已安裝" : @"未安裝"
                                     note:helper ? @"安裝後可在 App 內一鍵重啟 SpringBoard" : @"安裝桌寵插件時會一併裝上"
                                    state:helper ? DSHStateOK : DSHStateWarn]];

    return items;
}

+ (NSString *)reportText {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"DSH 桌寵 · 診斷報告\n"];
    [s appendFormat:@"時間：%@\n", [NSDate date]];

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    [s appendFormat:@"App 版本：%@ (%@)\n", info[@"CFBundleShortVersionString"], info[@"CFBundleVersion"]];
    [s appendFormat:@"系統版本：%@ %@\n", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
    struct utsname u;
    if (uname(&u) == 0) {
        [s appendFormat:@"機型：%s · %s\n", u.machine, u.version];
    }
    [s appendFormat:@"App 路徑：%@\n", [[NSBundle mainBundle] bundlePath]];
    [s appendFormat:@"越獄根目錄可讀：%@\n", [self hasJailbreakAccess] ? @"是" : @"否"];
    [s appendString:@"\n"];

    for (DSHStatusItem *item in [self statusItems]) {
        NSString *mark = item.state == DSHStateOK ? @"[OK]" : (item.state == DSHStateWarn ? @"[!!]" : @"[X]");
        [s appendFormat:@"%@ %@：%@\n", mark, item.title, item.value];
        if (item.note.length > 0) [s appendFormat:@"      %@\n", item.note];
    }

    [s appendString:@"\n路徑檢查：\n"];
    for (NSString *p in @[kDylibPath, kFilterPath, kAssetsDir, kHelperPath, @"/var/jb", @"/var/jb/usr/bin/sbreload"]) {
        [s appendFormat:@"  %@ → %@\n", p, DSHPathExists(p) ? @"存在" : @"不存在"];
    }
    return s;
}

+ (NSURL *)bundledDebURL {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"DSHPet" ofType:@"deb"];
    if (path.length == 0) {
        NSString *alt = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"DSHPet.deb"];
        if (DSHPathExists(alt)) path = alt;
    }
    return path.length > 0 ? [NSURL fileURLWithPath:path] : nil;
}

+ (NSURL *)preparedDebURL {
    NSURL *src = [self bundledDebURL];
    if (!src) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *srcAttr = [fm attributesOfItemAtPath:src.path error:NULL];
    unsigned long long srcSize = srcAttr ? [srcAttr[NSFileSize] unsignedLongLongValue] : 0;
    NSArray<NSString *> *targets = @[
        @"/var/mobile/Documents/DSHPet.deb",
        @"/var/tmp/DSHPet.deb",
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"DSHPet.deb"]
    ];
    for (NSString *dst in targets) {
        NSString *dir = [dst stringByDeletingLastPathComponent];
        if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL]) continue;
        NSDictionary *dstAttr = [fm attributesOfItemAtPath:dst error:NULL];
        unsigned long long dstSize = dstAttr ? [dstAttr[NSFileSize] unsignedLongLongValue] : 0;
        if (dstSize > 0 && dstSize == srcSize) return [NSURL fileURLWithPath:dst];
        [fm removeItemAtPath:dst error:NULL];
        NSError *err = nil;
        if ([fm copyItemAtURL:src toURL:[NSURL fileURLWithPath:dst] error:&err]) {
            NSLog(@"[DSHPet] deb staged at %@ (%llu bytes)", dst, srcSize);
            return [NSURL fileURLWithPath:dst];
        }
        NSLog(@"[DSHPet] staging deb at %@ failed: %@", dst, err);
    }
    return src;
}

+ (BOOL)pluginInstalled {
    return [[NSFileManager defaultManager] fileExistsAtPath:kDylibPath];
}

#pragma mark - 桌宠开关

+ (BOOL)petEnabled {
    return !DSHPetDisabledByFlag();
}

+ (BOOL)setPetEnabled:(BOOL)enabled {
    BOOL now = DSHPetSetEnabled(enabled);
    if (now != enabled) {
        // 写不进 /var/jb/Library/DSHPet/ —— 多半是 postinst 没跑过，目录还是 root 755
        NSLog(@"[DSHPet] toggle failed, want=%d got=%d path=%@", (int)enabled, (int)now, DSHPetToggleFlagPath());
        return now;
    }
    // 通知 SpringBoard 里的 tweak 立刻响应，不需要 respring
    DSHPetPostToggleNotification();
    return now;
}

#pragma mark - 一键安装（走 setuid 助手，不依赖 Sileo）

+ (BOOL)helperInstalled {
    return DSHPathExists(kHelperPath) && access(kHelperPath.fileSystemRepresentation, X_OK) == 0;
}

+ (nullable NSURL *)bundledPayloadURL {
    NSBundle *bundle = [NSBundle mainBundle];
    // 轻量版叫 payload_light.tar.gz，完整版叫 payload.tar.gz，两个名字都认
    for (NSString *name in @[@"payload", @"payload_light"]) {
        NSString *p = [bundle pathForResource:name ofType:@"tar.gz"];
        if (p) return [NSURL fileURLWithPath:p];
    }
    for (NSString *name in @[@"payload.tar.gz", @"payload_light.tar.gz"]) {
        NSString *p = [bundle.bundlePath stringByAppendingPathComponent:name];
        if (DSHPathExists(p)) return [NSURL fileURLWithPath:p];
    }
    return nil;
}

// 让助手把 payload 解到 /var/jb，并在里面完成 chown/chmod/签名/trustcache/respring。
// 会阻塞十几秒（解 140 MB + 逐个 ldid），调用方要放到后台队列。
+ (BOOL)installViaHelper:(nullable NSString *)payloadPath {
    if (![self helperInstalled]) return NO;
    NSURL *payload = payloadPath ? [NSURL fileURLWithPath:payloadPath] : [self bundledPayloadURL];
    if (!payload) return NO;
    return DSHExecute(kHelperPath, @[@"install", payload.path]);
}

+ (BOOL)uninstallViaHelper {
    if (![self helperInstalled]) return NO;
    return DSHExecute(kHelperPath, @[@"uninstall"]);
}

+ (BOOL)respring {
    if (DSHExecute(kHelperPath, @[])) return YES;
    if (DSHExecute(@"/var/jb/usr/bin/sbreload", @[])) return YES;
    if (DSHExecute(@"/usr/bin/sbreload", @[])) return YES;
    if (DSHExecute(@"/var/jb/usr/bin/killall", @[@"-9", @"SpringBoard"])) return YES;
    if (DSHExecute(@"/usr/bin/killall", @[@"-9", @"SpringBoard"])) return YES;
    return NO;
}

+ (nullable NSString *)writeReportFile:(NSString *)text prefix:(NSString *)prefix {
    // 为什么不用 UIActivityViewController：ShareSheet（iOS 16 的 _UIActivityContentCollectionView）
    // 在这台越狱机上会在自己的 diffable data source 里越界崩溃，栈顶是
    // -[__NSArrayM removeObjectsInRange:] / -[__NSArrayM count]，与本 App 的数据无关。
    // 所以报告改成「复制到剪贴板 + 落成文件」两条不经过系统扩展的路。
    NSString *dir = @"/var/mobile/Documents";
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        dir = NSTemporaryDirectory();
    }

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *stamp = [fmt stringFromDate:[NSDate date]];

    NSString *name = [NSString stringWithFormat:@"%@-%@.txt", prefix.length > 0 ? prefix : @"DSHPet-report", stamp];
    NSString *path = [dir stringByAppendingPathComponent:name];

    NSError *err = nil;
    if (![text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        NSLog(@"[DSHPet] write report failed: %@", err);
        return nil;
    }
    return path;
}

@end
