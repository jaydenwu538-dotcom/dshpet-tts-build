#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static inline CGFloat DSHPetClamp(CGFloat v, CGFloat lo, CGFloat hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

static inline CGFloat DSHPetRandom01(void) {
    return (CGFloat)arc4random_uniform(1000000) / 1000000.0;
}

static inline CGFloat DSHPetRandomBetween(CGFloat lo, CGFloat hi) {
    if (hi <= lo) return lo;
    return lo + (hi - lo) * DSHPetRandom01();
}

/** 从池中等概率取一个，尽量避开 exclude。 */
extern NSString * _Nullable DSHPetRandomFrom(NSArray<NSString *> *pool, NSString * _Nullable exclude);

/** 动画素材根目录（rootless 优先 /var/jb/Library/DSHPet/mov），找不到返回 nil。 */
extern NSString * _Nullable DSHPetAssetsRoot(void);

extern BOOL DSHPetDebugEnabled(void);

/** 动画名 -> 本地 mov URL；文件不存在返回 nil。 */
extern NSURL * _Nullable DSHPetURLForAnimation(NSString *name);

#define DSHPET_LOG(...) do { if (DSHPetDebugEnabled()) NSLog(@"[DSHPet] " __VA_ARGS__); } while (0)

/** 无条件追加一行到 /var/jb/Library/DSHPet/trace.log，不受 debug 开关影响。 */
extern void DSHPetTrace(NSString *fmt, ...);

NS_ASSUME_NONNULL_END
