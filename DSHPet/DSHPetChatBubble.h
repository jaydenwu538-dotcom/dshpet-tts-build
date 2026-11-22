#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 桌面上的小聊天泡：不跳 App，直接在這塊面板裡問一句、看回覆。
@interface DSHPetChatBubbleView : UIView

@property (nonatomic, copy, nullable) void (^onDismiss)(void);

// 回答會用頭頂的漫畫氣泡顯示，所以需要知道寵物在哪。
@property (nonatomic, weak, nullable) UIView *petAnchor;

- (void)showInWindow:(UIWindow *)window;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
