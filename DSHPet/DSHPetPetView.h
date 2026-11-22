#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 宠物视图：A/B 双播放器切换 + 手势。
 * 内部层级：self -> flipView（镜像）-> squashView（挤压）-> 两个 AVPlayerLayer。
 */
@interface DSHPetPetView : UIView

@property (nonatomic, readonly, nullable) NSString *playingAnim;
@property (nonatomic, readonly) BOOL playingOnce;

@property (nonatomic, copy, nullable) void (^onEnded)(NSString *name);
@property (nonatomic, copy, nullable) void (^onFrontReady)(void);
@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, copy, nullable) void (^onLongPress)(void);
@property (nonatomic, copy, nullable) void (^onDragBegan)(CGPoint location);
@property (nonatomic, copy, nullable) void (^onDragMoved)(CGPoint location, CGPoint velocity);
@property (nonatomic, copy, nullable) void (^onDragEnded)(CGPoint location, CGPoint velocity, BOOL wasDragging);

- (void)playAnimation:(NSString *)name once:(BOOL)once;
- (void)setFacingRight:(BOOL)right;
- (void)applySquash:(CGFloat)squash;
- (NSTimeInterval)videoDuration;
- (NSTimeInterval)videoTime;
- (void)pausePlayback;
- (void)resumePlayback;
- (void)disposePlayers;

@end

NS_ASSUME_NONNULL_END
