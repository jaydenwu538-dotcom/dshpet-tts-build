#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/** 单个 AVPlayer + AVPlayerLayer 的封装（HEVC-alpha 透明视频）。 */
@interface DSHPetPlayer : NSObject

@property (nonatomic, strong, readonly) AVPlayerLayer *layer;
@property (nonatomic, readonly) BOOL ready;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval currentTime;

@property (nonatomic, copy, nullable) void (^onReady)(void);
@property (nonatomic, copy, nullable) void (^onEnded)(void);

- (void)loadURL:(NSURL *)url loop:(BOOL)loop;
- (void)play;
- (void)pause;
- (void)teardown;

@end

NS_ASSUME_NONNULL_END
