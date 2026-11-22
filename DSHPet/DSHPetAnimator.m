#import "DSHPetAnimator.h"
#import "DSHPetCommon.h"
#import "DSHPetPhysics.h"
#import "DSHPetAnimTable.h"

static const CGFloat kDSHPetRefWidth = 462.0;
static const CGFloat kDSHPetClickSquash = 0.78;

#define DSHTrace(...) DSHPetTrace(__VA_ARGS__)

@interface DSHPetAnimator ()
@property (nonatomic, readwrite) DSHPetAnimatorState state;
@property (nonatomic, readwrite) BOOL facingRight;
@property (nonatomic, readwrite, copy, nullable) NSString *currentAnim;

@property (nonatomic, strong, nullable) CADisplayLink *link;
@property (nonatomic, strong, nullable) NSDictionary *walk;
@property (nonatomic) CGPoint velocity;
@property (nonatomic) CGFloat flyImpact;
@property (nonatomic) CGPoint dragOffset;
@property (nonatomic) BOOL dragAnimStarted;

@property (nonatomic) BOOL pendingSquash;
@property (nonatomic) CGFloat pendingSquashAmount;

@property (nonatomic) NSInteger sleepPhase; // 0 none / 1 start / 2 loop / 3 end
@end

@implementation DSHPetAnimator

- (BOOL)sleeping {
    return self.sleepPhase != 0;
}

#pragma mark - 生命周期

- (void)start {
    self.state = DSHPetAnimatorStateIdle;
    self.sleepPhase = 0;
    self.facingRight = NO;
    [self.view setFacingRight:NO];
    [self playAnim:DSHPetRandomFrom(DSHPetIdlePool(), nil) once:YES];
    DSHTrace(@"anim: start done");
}

- (void)stop {
    [self stopTicker];
    self.walk = nil;
    self.velocity = CGPointZero;
    self.sleepPhase = 0;
    self.state = DSHPetAnimatorStateIdle;
    [self.view pausePlayback];
}

#pragma mark - 播放

- (void)playAnim:(nullable NSString *)name once:(BOOL)once {
    NSString *anim = name;
    if (anim.length == 0) anim = DSHPetRandomFrom(DSHPetIdlePool(), nil);
    if (anim.length == 0) return;
    self.currentAnim = anim;
    [self.view playAnimation:anim once:once];
}

- (void)handleFrontReady {
    if (self.pendingSquash) {
        self.pendingSquash = NO;
        [self.view applySquash:self.pendingSquashAmount];
    }
}

#pragma mark - ended / 决策

- (void)handleEnded:(NSString *)name {
    if (self.state == DSHPetAnimatorStateDragging || self.state == DSHPetAnimatorStateFlying) return;
    if (self.walk) [self commitWalk];
    if (self.sleepPhase != 0) {
        [self handleSleepEnded];
        return;
    }
    [self resolveCue:name];
}

- (void)resolveCue:(NSString *)name {
    if ([DSHPetTurnPool() containsObject:name]) {
        self.facingRight = !self.facingRight;
        [self.view setFacingRight:self.facingRight];
        [self pickNext];
        return;
    }
    if ([DSHPetDragPool() containsObject:name] || [DSHPetClickPool() containsObject:name]) {
        [self playAnim:DSHPetRandomFrom(DSHPetIdlePool(), name) once:YES];
        return;
    }
    [self pickNext];
}

- (void)pickNext {
    if (self.state != DSHPetAnimatorStateIdle) return;

    CGFloat roll = DSHPetRandom01();
    const CGFloat idleW = 10.0 / 100.0;
    const CGFloat turnW = 5.0 / 100.0;
    const CGFloat moveW = 5.0 / 100.0;

    if (roll < idleW) {
        [self playAnim:DSHPetRandomFrom(DSHPetIdlePool(), self.currentAnim) once:YES];
        return;
    }
    if (roll < idleW + turnW) {
        [self playAnim:DSHPetRandomFrom(DSHPetTurnPool(), self.currentAnim) once:YES];
        return;
    }
    if (roll < idleW + turnW + moveW) {
        if ([self tryWalk]) return;
    }
    NSString *action = [self pickCategoryAction];
    [self playAnim:action ?: DSHPetRandomFrom(DSHPetIdlePool(), self.currentAnim) once:YES];
}

- (nullable NSString *)pickCategoryAction {
    NSArray<NSDictionary *> *cats = DSHPetCategories();
    NSMutableArray<NSDictionary *> *eligible = [NSMutableArray array];
    CGFloat total = 0;
    for (NSDictionary *c in cats) {
        NSArray *acts = c[@"actions"];
        if (acts.count == 0) continue;
        if (self.facingRight && [c[@"noMirror"] boolValue]) continue;
        [eligible addObject:c];
        total += [c[@"weight"] doubleValue];
    }
    if (eligible.count == 0 || total <= 0) return nil;
    CGFloat r = DSHPetRandom01() * total;
    for (NSDictionary *c in eligible) {
        r -= [c[@"weight"] doubleValue];
        if (r <= 0) {
            NSArray<NSString *> *acts = c[@"actions"];
            return acts[arc4random_uniform((uint32_t)acts.count)];
        }
    }
    return nil;
}

#pragma mark - 走位

- (BOOL)tryWalk {
    NSArray<NSDictionary *> *moves = DSHPetMoves();
    if (moves.count == 0) return NO;
    NSDictionary *mv = moves[arc4random_uniform((uint32_t)moves.count)];

    CGRect f = self.view.frame;
    CGRect screen = self.view.window.bounds;
    if (screen.size.width <= 0) return NO;

    CGFloat scale = CGRectGetWidth(f) / kDSHPetRefWidth;
    CGFloat minD = [mv[@"minDist"] doubleValue] * scale;
    CGFloat maxD = [mv[@"maxDist"] doubleValue] * scale;
    CGFloat margin = [mv[@"margin"] doubleValue];
    CGFloat dist = DSHPetRandomBetween(minD, maxD);

    CGFloat dir = self.facingRight ? 1.0 : -1.0;
    CGFloat cx = CGRectGetMidX(f);
    CGFloat halfW = CGRectGetWidth(f) / 2.0;
    CGFloat targetX = cx + dir * dist;
    CGFloat leftBound = margin + halfW;
    CGFloat rightBound = CGRectGetWidth(screen) - margin - halfW;
    if (targetX < leftBound || targetX > rightBound) return NO;

    self.walk = @{
        @"from": @(cx),
        @"to": @(targetX),
        @"lead": @([mv[@"leadSec"] doubleValue]),
        @"tail": @([mv[@"tailSec"] doubleValue]),
    };
    [self playAnim:mv[@"name"] once:YES];
    [self startTicker];
    return YES;
}

- (void)stepWalk {
    NSDictionary *walk = self.walk;
    if (!walk) return;
    NSTimeInterval dur = self.view.videoDuration;
    NSTimeInterval t = self.view.videoTime;
    CGFloat lead = [walk[@"lead"] doubleValue];
    CGFloat tail = [walk[@"tail"] doubleValue];
    if (dur <= 0) dur = lead + tail + 1.0;

    CGFloat u;
    if (t <= lead) {
        u = 0;
    } else if (t >= dur - tail) {
        u = 1;
    } else {
        u = (CGFloat)(t - lead) / MAX(0.001, (CGFloat)(dur - lead - tail));
    }
    CGFloat from = [walk[@"from"] doubleValue];
    CGFloat to = [walk[@"to"] doubleValue];
    CGFloat x = from + (to - from) * u;

    CGRect f = self.view.frame;
    f.origin.x = x - CGRectGetWidth(f) / 2.0;
    self.view.frame = f;
}

- (void)commitWalk {
    NSDictionary *walk = self.walk;
    self.walk = nil;
    if (!walk) return;
    CGRect f = self.view.frame;
    f.origin.x = [walk[@"to"] doubleValue] - CGRectGetWidth(f) / 2.0;
    CGRect screen = self.view.window.bounds;
    f.origin.x = DSHPetClamp(f.origin.x, 0, MAX(0, screen.size.width - CGRectGetWidth(f)));
    self.view.frame = f;
}

#pragma mark - 点击

- (void)handleTap {
    if (self.sleeping) return;
    // 单击时 pan 手势的 began 已把状态设为 Dragging；若尚未真正拖动，则复位成 Idle 接受点击。
    if (self.state == DSHPetAnimatorStateDragging) {
        if (self.dragAnimStarted) return;
        self.state = DSHPetAnimatorStateIdle;
    }
    if (self.state != DSHPetAnimatorStateIdle) return;
    [self commitWalk];
    NSString *anim = DSHPetRandomFrom(DSHPetClickPool(), self.currentAnim);
    if (!anim) return;
    [self playAnim:anim once:YES];
    self.pendingSquash = YES;
    self.pendingSquashAmount = kDSHPetClickSquash;
}

#pragma mark - 拖拽

- (void)cancelDrag {
    if (self.state == DSHPetAnimatorStateDragging) {
        self.state = DSHPetAnimatorStateIdle;
        self.dragAnimStarted = NO;
        self.walk = nil;
        [self stopTicker];
    }
}

- (void)beginDragAt:(CGPoint)location {
    if (self.sleeping) return;
    [self stopFlight];
    [self commitWalk];
    self.state = DSHPetAnimatorStateDragging;
    self.dragAnimStarted = NO;
    CGRect f = self.view.frame;
    self.dragOffset = CGPointMake(location.x - f.origin.x, location.y - f.origin.y);
}

- (void)dragMovedTo:(CGPoint)location {
    if (self.sleeping || self.state != DSHPetAnimatorStateDragging) return;
    CGRect f = self.view.frame;
    f.origin.x = location.x - self.dragOffset.x;
    f.origin.y = location.y - self.dragOffset.y;
    self.view.frame = f;
    if (!self.dragAnimStarted) {
        self.dragAnimStarted = YES;
        [self playAnim:DSHPetRandomFrom(DSHPetDragPool(), nil) once:YES];
    }
}

- (void)endDragAt:(CGPoint)location velocity:(CGPoint)velocity {
    if (self.sleeping) {
        return;
    }
    if (self.state != DSHPetAnimatorStateDragging) {
        self.state = DSHPetAnimatorStateIdle;
        return;
    }
    self.state = DSHPetAnimatorStateIdle;
    self.dragAnimStarted = NO;

    CGFloat speed = hypot(velocity.x, velocity.y);
    if (speed < 500.0) {
        [self playAnim:DSHPetRandomFrom(DSHPetIdlePool(), self.currentAnim) once:YES];
        return;
    }
    self.velocity = velocity;
    self.flyImpact = 0;
    self.state = DSHPetAnimatorStateFlying;
    [self playAnim:DSHPetRandomFrom(DSHPetIdlePool(), self.currentAnim) once:NO];
    [self startTicker];
}

#pragma mark - 飞行

- (void)stepFlight:(NSTimeInterval)dt {
    int n = DSHPetSubsteps(self.velocity, dt);
    CGFloat sub = (CGFloat)dt / (CGFloat)n;
    CGRect f = self.view.frame;
    CGRect screen = self.view.window.bounds;
    CGFloat w = f.size.width, h = f.size.height;
    CGFloat W = screen.size.width, H = screen.size.height;
    CGFloat side = 24.0;
    CGPoint p = f.origin;
    CGPoint v = self.velocity;
    CGFloat impact = 0;

    for (int i = 0; i < n; i++) {
        v.y += DSHPetGravity * sub;
        p.x += v.x * sub;
        p.y += v.y * sub;

        if (p.x < -side) {
            p.x = -side;
            impact = MAX(impact, fabs(v.x));
            v = DSHPetContactVelocity(v, CGPointMake(1, 0), DSHPetRestitution, 0, sub);
        }
        if (p.x + w > W + side) {
            p.x = W + side - w;
            impact = MAX(impact, fabs(v.x));
            v = DSHPetContactVelocity(v, CGPointMake(-1, 0), DSHPetRestitution, 0, sub);
        }
        if (p.y < 0) {
            p.y = 0;
            impact = MAX(impact, fabs(v.y));
            v = DSHPetContactVelocity(v, CGPointMake(0, 1), DSHPetRestitution, 0, sub);
        }
        if (p.y + h > H) {
            p.y = H - h;
            impact = MAX(impact, fabs(v.y));
            v = DSHPetContactVelocity(v, CGPointMake(0, -1), DSHPetRestitution, DSHPetGroundFriction, sub);
        }
    }

    f.origin = p;
    self.view.frame = f;
    self.velocity = v;
    if (impact > 0) self.flyImpact = MAX(self.flyImpact, impact);

    BOOL onGround = (p.y + h >= H - 0.5);
    if (onGround && fabs(v.y) < 60.0 && fabs(v.x) < 80.0) {
        [self endFlight];
    }
}

- (void)endFlight {
    CGFloat impact = self.flyImpact;
    self.flyImpact = 0;
    self.velocity = CGPointZero;
    self.state = DSHPetAnimatorStateIdle;
    self.walk = nil;
    [self stopTicker];
    [self.view applySquash:DSHPetLandingSquash(impact)];
    [self playAnim:DSHPetRandomFrom(DSHPetIdlePool(), self.currentAnim) once:YES];
}

- (void)stopFlight {
    if (self.state != DSHPetAnimatorStateFlying) return;
    self.state = DSHPetAnimatorStateIdle;
    self.velocity = CGPointZero;
    [self stopTicker];
}

#pragma mark - 睡眠

- (void)toggleSleep {
    if (self.sleeping) {
        [self wake];
    } else {
        [self sleep];
    }
}

- (void)sleep {
    if (self.sleeping) return;
    [self stopTicker];
    [self commitWalk];
    self.state = DSHPetAnimatorStateSleeping;
    self.sleepPhase = 1;
    [self playAnim:DSHPetSleepStartPool().firstObject once:YES];
}

- (void)wake {
    if (!self.sleeping) return;
    self.sleepPhase = 3;
    self.state = DSHPetAnimatorStateIdle;
    [self playAnim:DSHPetSleepEndPool().firstObject once:YES];
}

- (void)handleSleepEnded {
    if (self.sleepPhase == 1) {
        self.sleepPhase = 2;
        [self playAnim:DSHPetSleepLoopPool().firstObject once:NO];
        return;
    }
    if (self.sleepPhase == 3) {
        self.sleepPhase = 0;
        [self pickNext];
        return;
    }
    // loop 期间不应收到 ended；兜底重播
    if (self.sleepPhase == 2) {
        [self playAnim:DSHPetSleepLoopPool().firstObject once:NO];
    }
}

#pragma mark - 其它

- (void)randomAction {
    if (self.sleeping || self.state != DSHPetAnimatorStateIdle) return;
    [self commitWalk];
    NSString *action = [self pickCategoryAction];
    [self playAnim:action ?: DSHPetRandomFrom(DSHPetIdlePool(), self.currentAnim) once:YES];
}

- (void)playSpecial:(NSString *)name {
    if (name.length == 0 || self.sleeping) return;
    [self stopFlight];
    [self commitWalk];
    self.state = DSHPetAnimatorStateIdle;
    [self playAnim:name once:YES];
}

- (void)setFacingRight:(BOOL)right {
    // 注意：这里必须直接写 ivar。写成 self.facingRight = right 会调用自己，无限递归爆栈。
    _facingRight = right;
    [self.view setFacingRight:right];
}

#pragma mark - ticker

- (void)startTicker {
    if (self.link) return;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopTicker {
    [self.link invalidate];
    self.link = nil;
}

- (void)tick:(CADisplayLink *)link {
    NSTimeInterval dt = link.targetTimestamp - link.timestamp;
    if (dt <= 0 || dt > 0.1) dt = 1.0 / 60.0;
    if (self.state == DSHPetAnimatorStateFlying) {
        [self stepFlight:dt];
    } else if (self.walk) {
        [self stepWalk];
    } else {
        [self stopTicker];
    }
}

- (void)dealloc {
    [self.link invalidate];
}

@end
