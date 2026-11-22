#pragma once
#import <UIKit/UIKit.h>
#import "DSHPetPetView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSHPetAnimatorState) {
    DSHPetAnimatorStateIdle = 0,
    DSHPetAnimatorStateDragging,
    DSHPetAnimatorStateFlying,
    DSHPetAnimatorStateSleeping,
};

/** 行为调度：随机链 / 走位 / 拖拽甩抛 / 点击 / 睡眠。 */
@interface DSHPetAnimator : NSObject

@property (nonatomic, weak, nullable) DSHPetPetView *view;
@property (nonatomic, copy, nullable) void (^onLongPress)(void);

@property (nonatomic, readonly) DSHPetAnimatorState state;
@property (nonatomic, readonly) BOOL sleeping;
@property (nonatomic, readonly) BOOL facingRight;
@property (nonatomic, readonly, nullable) NSString *currentAnim;

- (void)start;
- (void)stop;
- (void)toggleSleep;
- (void)randomAction;
- (void)playSpecial:(NSString *)name;
- (void)setFacingRight:(BOOL)right;

// PetView 事件转发
- (void)handleEnded:(NSString *)name;
- (void)handleFrontReady;
- (void)handleTap;
- (void)cancelDrag;
- (void)beginDragAt:(CGPoint)location;
- (void)dragMovedTo:(CGPoint)location;
- (void)endDragAt:(CGPoint)location velocity:(CGPoint)velocity;

@end

NS_ASSUME_NONNULL_END
