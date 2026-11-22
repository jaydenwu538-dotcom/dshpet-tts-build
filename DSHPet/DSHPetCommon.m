#import "DSHPetCommon.h"
#include <fcntl.h>
#include <stdarg.h>
#include <time.h>
#include <unistd.h>

void DSHPetTrace(NSString *fmt, ...) {
    // 默认不写日志：只有 touch /var/jb/Library/DSHPet/trace 时才开启，避免长期占用存储。
    static BOOL enabled;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        enabled = [fm fileExistsAtPath:@"/var/jb/Library/DSHPet/trace"]
               || [fm fileExistsAtPath:@"/Library/DSHPet/trace"];
    });
    if (!enabled) return;
    @autoreleasepool {
        va_list ap;
        va_start(ap, fmt);
        NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);
        if (!msg) return;
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        NSString *line = [NSString stringWithFormat:@"%lld.%03ld pid=%d %@\n",
                          (long long)ts.tv_sec, ts.tv_nsec / 1000000, getpid(), msg];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        NSString *dir = @"/var/jb/Library/DSHPet";
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            dir = NSTemporaryDirectory();
        }
        NSString *path = [dir stringByAppendingPathComponent:@"trace.log"];
        int fd = open([path fileSystemRepresentation], O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            write(fd, data.bytes, data.length);
            close(fd);
        }
    }
}

NSString * _Nullable DSHPetRandomFrom(NSArray<NSString *> *pool, NSString * _Nullable exclude) {
    if (pool.count == 0) return nil;
    NSMutableArray<NSString *> *cand = [NSMutableArray arrayWithCapacity:pool.count];
    for (NSString *s in pool) {
        if (exclude && [s isEqualToString:exclude]) continue;
        [cand addObject:s];
    }
    if (cand.count == 0) cand = [pool mutableCopy];
    return cand[arc4random_uniform((uint32_t)cand.count)];
}

NSString *DSHPetAssetsRoot(void) {
    static NSString *root;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray<NSString *> *cands = [NSMutableArray array];
        // 安装器 App 内自带一份资源时优先用它（SpringBoard 里 mainBundle 没有 mov，会被跳过）
        NSString *bundled = [[NSBundle mainBundle] pathForResource:@"mov" ofType:nil];
        if (bundled.length > 0) [cands addObject:bundled];
        [cands addObject:@"/var/jb/Library/DSHPet/mov"];
        [cands addObject:@"/Library/DSHPet/mov"];
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (docs.length > 0) [cands addObject:[docs stringByAppendingPathComponent:@"mov"]];
        for (NSString *c in cands) {
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:c isDirectory:&isDir] && isDir) {
                root = c;
                break;
            }
        }
        if (!root) DSHPET_LOG(@"assets root not found (expected /var/jb/Library/DSHPet/mov)");
    });
    return root;
}

BOOL DSHPetDebugEnabled(void) {
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 开日志：touch /var/jb/Library/DSHPet/debug（或设置环境变量 DSHPET_DEBUG=1）
        NSArray<NSString *> *flags = @[
            @"/var/jb/Library/DSHPet/debug",
            @"/Library/DSHPet/debug",
        ];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *f in flags) {
            if ([fm fileExistsAtPath:f]) {
                enabled = YES;
                return;
            }
        }
        NSString *env = [[NSProcessInfo processInfo] environment][@"DSHPET_DEBUG"];
        if (env.length > 0 && ![env isEqualToString:@"0"]) enabled = YES;
    });
    return enabled;
}

NSURL * _Nullable DSHPetURLForAnimation(NSString *name) {
    if (name.length == 0) return nil;
    NSString *root = DSHPetAssetsRoot();
    if (!root) return nil;
    NSString *path = [root stringByAppendingPathComponent:[name stringByAppendingString:@".mov"]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        DSHPET_LOG(@"asset missing: %@", path);
        return nil;
    }
    return [NSURL fileURLWithPath:path];
}
