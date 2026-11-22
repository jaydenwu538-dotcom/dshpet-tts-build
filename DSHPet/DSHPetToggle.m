#import "DSHPetToggle.h"
#import "DSHPetCommon.h"

#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

static NSString *const kDSHPetToggleNotify = @"com.jayden.dshpet.toggle";
static void (^gDSHPetToggleHandler)(void) = nil;

NSString *DSHPetToggleFlagPath(void) {
    NSString *dir = @"/var/jb/Library/DSHPet";
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        // 非 rootless 环境（老式 /Library/DSHPet）
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/DSHPet"]) {
            dir = @"/Library/DSHPet";
        }
    }
    return [dir stringByAppendingPathComponent:@"disabled"];
}

BOOL DSHPetDisabledByFlag(void) {
    return [[NSFileManager defaultManager] fileExistsAtPath:DSHPetToggleFlagPath()];
}

BOOL DSHPetSetEnabled(BOOL enabled) {
    NSString *path = DSHPetToggleFlagPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (enabled) {
        [fm removeItemAtPath:path error:NULL];
    } else {
        NSString *dir = [path stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        NSData *payload = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
        [payload writeToFile:path atomically:YES];
    }
    return !DSHPetDisabledByFlag();
}

void DSHPetPostToggleNotification(void) {
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center,
                                         (__bridge CFStringRef)kDSHPetToggleNotify,
                                         NULL, NULL, true);
    DSHPetTrace(@"toggle: posted notification");
}

static void DSHPetToggleCallback(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    void (^handler)(void) = gDSHPetToggleHandler;
    if (!handler) return;
    // Darwin notification 回调不在主线程，UI 操作必须切回主线程
    dispatch_async(dispatch_get_main_queue(), ^{
        handler();
    });
}

void DSHPetObserveToggle(void (^handler)(void)) {
    gDSHPetToggleHandler = [handler copy];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    DSHPetToggleCallback,
                                    (__bridge CFStringRef)kDSHPetToggleNotify,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    DSHPetTrace(@"toggle: observer installed");
}

// Darwin notification 的回调注册在 notifyd 上，进程退出即失效。
// SpringBoard 的 tweak dylib 会随 SpringBoard 生命期一直存在，这里不需要显式移除。
