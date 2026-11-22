#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSHPetManager : NSObject

+ (instancetype)shared;

- (void)start;
- (void)stop;

/** 按开关文件（/var/jb/Library/DSHPet/disabled）的实际状态同步桌宠显隐。 */
- (void)applyToggleState;

@end

NS_ASSUME_NONNULL_END
