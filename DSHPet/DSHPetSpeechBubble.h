#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 漫画式的对话泡泡：白底圆角 + 指向下方的小尾巴，浮在宠物头顶。
@interface DSHPetSpeechBubbleView : UIView

// anchor 是宠物视图（same window 坐标系）。会先收起已有的泡泡。
+ (void)showText:(NSString *)text aboveView:(nullable UIView *)anchor inWindow:(nullable UIWindow *)window;
+ (void)hide;

@end

NS_ASSUME_NONNULL_END
