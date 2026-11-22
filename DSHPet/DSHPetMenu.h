#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSHPetMenuAction) {
    DSHPetMenuActionSleepToggle = 100,
    DSHPetMenuActionChat,
    DSHPetMenuActionRandomAction,
    DSHPetMenuActionHome,
    DSHPetMenuActionSizeSmall,
    DSHPetMenuActionSizeMedium,
    DSHPetMenuActionSizeLarge,
    DSHPetMenuActionHide,
};

@interface DSHPetMenuView : UIView

@property (nonatomic, copy, nullable) void (^onAction)(DSHPetMenuAction action);
@property (nonatomic, copy, nullable) void (^onDismiss)(void);

- (instancetype)initWithSleeping:(BOOL)sleeping;
- (void)showInWindow:(UIWindow *)window;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
