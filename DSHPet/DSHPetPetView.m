#import "DSHPetPetView.h"
#import "DSHPetPlayer.h"
#import "DSHPetCommon.h"
#import "DSHPetPhysics.h"
#import "DSHPetAnimTable.h"

static const CGFloat kDSHPetDragThreshold = 5.0;
static const CFTimeInterval kDSHPetTrailWindow = 0.2;

#define DSHTrace(...) DSHPetTrace(__VA_ARGS__)

@interface DSHPetPetView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *flipView;
@property (nonatomic, strong) UIView *squashView;
@property (nonatomic, strong) DSHPetPlayer *playerA;
@property (nonatomic, strong) DSHPetPlayer *playerB;
@property (nonatomic) NSInteger frontIndex;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;

@property (nonatomic) CGPoint dragStart;
@property (nonatomic) BOOL dragging;
@property (nonatomic) BOOL suppressTap;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *trail;
@property (nonatomic) CGPoint lastTouch;
@property (nonatomic) CFTimeInterval lastTouchTime;
@end

@implementation DSHPetPetView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.userInteractionEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingNone;

    self.flipView = [[UIView alloc] initWithFrame:self.bounds];
    self.flipView.backgroundColor = [UIColor clearColor];
    self.flipView.opaque = NO;
    self.flipView.userInteractionEnabled = NO;
    [self addSubview:self.flipView];

    self.squashView = [[UIView alloc] initWithFrame:self.bounds];
    self.squashView.backgroundColor = [UIColor clearColor];
    self.squashView.opaque = NO;
    self.squashView.userInteractionEnabled = NO;
    [self.flipView addSubview:self.squashView];

    self.playerA = [DSHPetPlayer new];
    self.playerB = [DSHPetPlayer new];
    [self.squashView.layer addSublayer:self.playerA.layer];
    [self.squashView.layer addSublayer:self.playerB.layer];
    self.frontIndex = 0;

    self.trail = [NSMutableArray array];

    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.pan.maximumNumberOfTouches = 1;
    self.pan.cancelsTouchesInView = YES;
    self.pan.delegate = self;
    [self addGestureRecognizer:self.pan];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.5;
    lp.allowableMovement = 12;
    [self addGestureRecognizer:lp];

    // 点击必须用 tap 识别器：UIPanGestureRecognizer 在手指没移动时不会进入 ended，
    // 所以「单击」永远不会走 handlePan 的 ended 分支。
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tap.numberOfTapsRequired = 1;
    [self addGestureRecognizer:tap];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.flipView.frame = self.bounds;
    CGRect b = self.flipView.bounds;
    self.squashView.bounds = b;
    self.squashView.layer.anchorPoint = CGPointMake(0.5, 1.0);
    self.squashView.layer.position = CGPointMake(CGRectGetMidX(b), CGRectGetMaxY(b));
    self.playerA.layer.frame = b;
    self.playerB.layer.frame = b;
}

#pragma mark - 播放

- (DSHPetPlayer *)frontPlayer {
    return (self.frontIndex == 0) ? self.playerA : self.playerB;
}

- (DSHPetPlayer *)backPlayer {
    return (self.frontIndex == 0) ? self.playerB : self.playerA;
}

- (void)playAnimation:(NSString *)name once:(BOOL)once {
    if (name.length == 0) return;

    NSString *resolved = name;
    NSURL *url = DSHPetURLForAnimation(name);
    if (!url) {
        NSString *fallback = DSHPetIdlePool().firstObject;
        resolved = fallback;
        url = DSHPetURLForAnimation(fallback);
    }
    if (!url) {
        DSHPET_LOG(@"no asset for animation %@", name);
        return;
    }

    DSHPetPlayer *next = self.backPlayer;
    self.generation++;
    NSUInteger gen = self.generation;

    __weak typeof(self) weakSelf = self;
    __weak DSHPetPlayer *weakNext = next;
    next.onReady = ^{
        __strong typeof(weakSelf) self2 = weakSelf;
        DSHPetPlayer *next2 = weakNext;
        if (!self2 || !next2 || gen != self2.generation) return;
        DSHPetPlayer *old = [self2 frontPlayer];
        if (old != next2) {
            [old pause];
            old.layer.hidden = YES;
        }
        next2.layer.hidden = NO;
        self2.frontIndex = (self2.frontIndex == 0) ? 1 : 0;
        self2->_playingAnim = [resolved copy];
        self2->_playingOnce = once;
        [next2 play];
        if (self2.onFrontReady) self2.onFrontReady();
    };
    next.onEnded = ^{
        __strong typeof(weakSelf) self2 = weakSelf;
        if (!self2 || gen != self2.generation) return;
        if (![self2->_playingAnim isEqualToString:resolved]) return;
        if (self2.onEnded) self2.onEnded(resolved);
    };
    [next loadURL:url loop:!once];
}

- (void)setFacingRight:(BOOL)right {
    self.flipView.layer.transform = CATransform3DMakeScale(right ? -1.0 : 1.0, 1.0, 1.0);
}

- (void)applySquash:(CGFloat)squash {
    if (squash >= 0.999) return;
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    NSMutableArray *values = [NSMutableArray array];
    const int N = 14;
    for (int i = 0; i <= N; i++) {
        CGFloat u = (CGFloat)i / (CGFloat)N;
        CGFloat sy = DSHPetSquashScale(u, squash);
        CGFloat sx = 1.0 + (1.0 - sy) * 0.5;
        [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(sx, sy, 1.0)]];
    }
    anim.values = values;
    anim.duration = 0.22;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.squashView.layer addAnimation:anim forKey:@"squash"];
}

- (NSTimeInterval)videoDuration {
    return [self frontPlayer].duration;
}

- (NSTimeInterval)videoTime {
    return [self frontPlayer].currentTime;
}

- (void)pausePlayback {
    [self.frontPlayer pause];
}

- (void)resumePlayback {
    [self.frontPlayer play];
}

- (void)disposePlayers {
    [self.playerA teardown];
    [self.playerB teardown];
    [self.playerA.layer removeFromSuperlayer];
    [self.playerB.layer removeFromSuperlayer];
}

#pragma mark - 手势

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    // tap 与 pan 需要共存：pan 负责拖动，tap 负责单击。
    return YES;
}

- (void)handleTapGesture:(UITapGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateEnded) return;
    BOOL suppressed = self.suppressTap;
    self.suppressTap = NO;
    if (suppressed || self.dragging) return;
    if (self.onTap) self.onTap();
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    // 长按已经弹出菜单，别再让 tap 触发点击
    self.suppressTap = YES;
    // 重置 pan，避免长按后残留状态
    self.pan.enabled = NO;
    self.pan.enabled = YES;
    if (self.onLongPress) self.onLongPress();
}

- (CGPoint)locationInScreen:(UIGestureRecognizer *)g {
    return [g locationInView:self.window];
}

- (void)recordTrail:(CGPoint)p {
    CFTimeInterval now = CACurrentMediaTime();
    [self.trail addObject:@{@"t": @(now), @"p": [NSValue valueWithCGPoint:p]}];
    while (self.trail.count > 2 && [[self.trail firstObject][@"t"] doubleValue] < now - kDSHPetTrailWindow) {
        [self.trail removeObjectAtIndex:0];
    }
}

- (CGPoint)trailVelocity {
    if (self.trail.count < 2) return CGPointZero;
    NSDictionary *first = self.trail.firstObject;
    NSDictionary *last = self.trail.lastObject;
    CFTimeInterval dt = [last[@"t"] doubleValue] - [first[@"t"] doubleValue];
    if (dt < 0.02) return CGPointZero;
    CGPoint p0 = [first[@"p"] CGPointValue];
    CGPoint p1 = [last[@"p"] CGPointValue];
    CGPoint v = CGPointMake((p1.x - p0.x) / dt, (p1.y - p0.y) / dt);
    CGFloat speed = hypot(v.x, v.y);
    if (speed < 500.0) return CGPointZero;
    return CGPointMake(v.x, v.y);
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint p = [self locationInScreen:g];

    if (g.state == UIGestureRecognizerStateBegan) {
        self.dragStart = p;
        self.lastTouch = p;
        self.lastTouchTime = CACurrentMediaTime();
        self.dragging = NO;
        self.suppressTap = NO;
        [self.trail removeAllObjects];
        [self recordTrail:p];
        if (self.onDragBegan) self.onDragBegan(p);
        return;
    }

    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [g translationInView:self.window];
        if (!self.dragging && hypot(t.x, t.y) >= kDSHPetDragThreshold) {
            self.dragging = YES;
        }
        [self recordTrail:p];
        if (self.dragging) {
            CGFloat dt = CACurrentMediaTime() - self.lastTouchTime;
            CGPoint v = (dt > 0.001) ? CGPointMake((p.x - self.lastTouch.x) / dt, (p.y - self.lastTouch.y) / dt) : CGPointZero;
            self.lastTouch = p;
            self.lastTouchTime = CACurrentMediaTime();
            if (self.onDragMoved) self.onDragMoved(p, v);
        }
        return;
    }

    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        [self recordTrail:p];
        BOOL dragged = self.dragging;
        CGPoint v = [self trailVelocity];
        self.dragging = NO;
        [self.trail removeAllObjects];
        if (dragged && g.state == UIGestureRecognizerStateEnded) {
            if (self.onDragEnded) self.onDragEnded(p, v, YES);
        }
    }
}

- (void)dealloc {
    [self disposePlayers];
}

@end
