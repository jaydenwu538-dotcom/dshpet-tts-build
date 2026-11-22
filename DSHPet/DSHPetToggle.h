#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Tweak.xm 会被编成 Objective-C++。不加 extern "C" 的话，下面这些函数声明会被 C++
// name mangling 成 __Z20DSHPetObserveToggleU13block_pointerFvvE 之类，
// 与 DSHPetToggle.m 导出的 C 符号对不上，链接阶段报 undefined symbol。
#ifdef __cplusplus
extern "C" {
#endif

extern NSString *DSHPetToggleFlagPath(void);

/** 是否被开关关掉了。 */
extern BOOL DSHPetDisabledByFlag(void);

/** 写入开关状态；返回操作之后的实际状态（YES = 开启）。 */
extern BOOL DSHPetSetEnabled(BOOL enabled);

/** 广播状态变化，跨进程（App → SpringBoard）。 */
extern void DSHPetPostToggleNotification(void);

/** 在 SpringBoard 进程内注册监听，状态变化时回调（回调在主线程）。 */
extern void DSHPetObserveToggle(void (^handler)(void));

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
