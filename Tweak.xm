#import <Foundation/Foundation.h>
#import "DSHPet/DSHPetManager.h"
#import "DSHPet/DSHPetToggle.h"

// 无条件落盘，用来验证 dylib 到底有没有被注入器加载（不依赖 debug 开关）。
static void DSHPetBootLog(NSString *msg) {
    NSString *dir = @"/var/jb/Library/DSHPet";
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        dir = NSTemporaryDirectory();
    }
    NSString *file = [dir stringByAppendingPathComponent:@"boot.log"];
    NSMutableString *all = [NSMutableString stringWithContentsOfFile:file
                                                           encoding:NSUTF8StringEncoding
                                                              error:NULL];
    if (!all) {
        all = [NSMutableString string];
    }
    [all appendFormat:@"%@ pid=%d %@\n", [NSDate date], getpid(), msg];
    [all writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

%ctor {
    @autoreleasepool {
        NSString *process = [NSProcessInfo processInfo].processName;
        DSHPetBootLog([NSString stringWithFormat:@"ctor process=%@", process]);
        if (![process isEqualToString:@"SpringBoard"]) {
            return;
        }
        // 安装器 App 里拨开关 -> Darwin notification -> 这里立刻显隐，不用 respring
        DSHPetObserveToggle(^{
            DSHPetBootLog(@"toggle notification received");
            [[DSHPetManager shared] applyToggleState];
        });
        // 等 SpringBoard 完成启动、窗口场景就绪后再挂宠物
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            DSHPetBootLog(@"about to call DSHPetManager start");
            [[DSHPetManager shared] start];
            DSHPetBootLog(@"DSHPetManager start returned");
        });
    }
}
