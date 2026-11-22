#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** 透明、只接管宠物与菜单区域的窗口。 */
@interface DSHPetWindow : UIWindow

@property (nonatomic, weak, nullable) UIView *petView;
@property (nonatomic, weak, nullable) UIView *menuView;
@property (nonatomic, weak, nullable) UIView *chatBubbleView;

@end

NS_ASSUME_NONNULL_END
