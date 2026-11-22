#import "DSHPetPlayer.h"
#import "DSHPetCommon.h"

@interface DSHPetPlayer ()
@property (nonatomic, strong, nullable) AVPlayer *player;
@property (nonatomic, strong, nullable) AVPlayerItem *item;
@property (nonatomic, readwrite) BOOL ready;
@property (nonatomic, readwrite) NSTimeInterval duration;
@property (nonatomic) BOOL loop;
@property (nonatomic) BOOL endedFired;
@property (nonatomic) BOOL observing;
@end

@implementation DSHPetPlayer

- (instancetype)init {
    if ((self = [super init])) {
        _layer = [AVPlayerLayer layer];
        _layer.videoGravity = AVLayerVideoGravityResizeAspect;
        _layer.backgroundColor = [UIColor clearColor].CGColor;
        _layer.opaque = NO;
        _layer.masksToBounds = NO;
        _layer.hidden = YES;
    }
    return self;
}

- (void)loadURL:(NSURL *)url loop:(BOOL)loop {
    [self teardown];
    self.loop = loop;
    self.endedFired = NO;
    self.ready = NO;
    self.duration = 0;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.item = [AVPlayerItem playerItemWithAsset:asset];
    self.player = [AVPlayer playerWithPlayerItem:self.item];
    self.player.muted = YES;
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    self.layer.player = self.player;

    [self.item addObserver:self forKeyPath:@"status" options:0 context:NULL];
    self.observing = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPlayToEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.item];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"] && object == self.item) {
        AVPlayerItemStatus status = self.item.status;
        if (status == AVPlayerItemStatusReadyToPlay) {
            self.ready = YES;
            CMTime d = self.item.duration;
            if (CMTIME_IS_NUMERIC(d)) self.duration = CMTimeGetSeconds(d);
            if (self.onReady) self.onReady();
        } else if (status == AVPlayerItemStatusFailed) {
            DSHPET_LOG(@"player item failed: %@", self.item.error);
        }
    }
}

- (void)didPlayToEnd:(NSNotification *)note {
    if (self.loop) {
        __weak typeof(self) weakSelf = self;
        [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            if (finished) [weakSelf.player play];
        }];
        return;
    }
    if (self.endedFired) return;
    self.endedFired = YES;
    if (self.onEnded) self.onEnded();
}

- (void)play {
    [self.player play];
}

- (void)pause {
    [self.player pause];
}

- (NSTimeInterval)currentTime {
    if (!self.player) return 0;
    CMTime t = self.player.currentTime;
    if (!CMTIME_IS_NUMERIC(t)) return 0;
    return CMTimeGetSeconds(t);
}

- (void)teardown {
    if (self.observing && self.item) {
        @try {
            [self.item removeObserver:self forKeyPath:@"status"];
        } @catch (__unused NSException *e) {
        }
    }
    self.observing = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.player pause];
    self.layer.player = nil;
    self.item = nil;
    self.player = nil;
    self.ready = NO;
    self.duration = 0;
}

- (void)dealloc {
    [self teardown];
}

@end
