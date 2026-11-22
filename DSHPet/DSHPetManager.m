#import "DSHPetManager.h"
#import <UIKit/UIKit.h>
#import <stdarg.h>
#import <unistd.h>
#import "DSHPetCommon.h"
#import "DSHPetWindow.h"
#import "DSHPetPetView.h"
#import "DSHPetAnimator.h"
#import "DSHPetMenu.h"
#import "DSHPetToggle.h"
#import "DSHPetChatBubble.h"
#import "DSHPetSpeechBubble.h"

static NSString *const kDSHPetSizeKey = @"DSHPetSize";
static NSString *const kDSHPetCornerKey = @"DSHPetCorner";

// 无条件落盘诊断：定位 start -> buildWithScene 在哪一步卡死主线程
#define DSHTrace(...) DSHPetTrace(__VA_ARGS__)

@interface DSHPetManager ()
@property (nonatomic) BOOL started;
@property (nonatomic) NSInteger retryCount;
@property (nonatomic, strong, nullable) DSHPetWindow *window;
@property (nonatomic, strong, nullable) DSHPetPetView *petView;
@property (nonatomic, strong, nullable) DSHPetAnimator *animator;
@property (nonatomic, strong, nullable) DSHPetMenuView *menu;
@end

@implementation DSHPetManager

+ (instancetype)shared {
    static DSHPetManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [DSHPetManager new];
    });
    return manager;
}

- (instancetype)init {
    if ((self = [super init])) {
        // 首次启动时 SpringBoard 可能还没有 UIWindowScene，等它激活后再补一次
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)applicationDidBecomeActive {
    if (self.started) return;
    self.retryCount = 0;
    [self start];
}

#pragma mark - 查找 scene

- (nullable UIWindowScene *)findScene {
    UIWindowScene *fallback = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)s;
        if (ws.activationState == UISceneActivationStateForegroundActive) return ws;
        if (!fallback) fallback = ws;
    }
    // SpringBoard 里 connectedScenes 常常是空的，退回用现有窗口携带的 scene
    if (!fallback) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.windowScene) {
                fallback = w.windowScene;
                break;
            }
        }
    }
    if (!fallback) {
        // 最后兜底：私有 scene 管理器里任意一个 UIWindowScene
        id manager = nil;
        @try {
            manager = [[UIApplication sharedApplication] valueForKey:@"_sceneManager"];
        } @catch (NSException *e) {
            manager = nil;
        }
        if (manager) {
            @try {
                NSSet *scenes = [manager valueForKey:@"scenes"];
                for (id s in scenes) {
                    if ([s isKindOfClass:[UIWindowScene class]]) {
                        fallback = (UIWindowScene *)s;
                        break;
                    }
                }
            } @catch (NSException *e) {
                fallback = nil;
            }
        }
    }
    return fallback;
}

- (CGRect)screenBounds {
    CGRect b = self.window ? self.window.bounds : CGRectZero;
    if (CGRectGetWidth(b) < 1 || CGRectGetHeight(b) < 1) {
        b = [UIScreen mainScreen].bounds;
    }
    return b;
}

#pragma mark - 启动

- (void)start {
    if (self.started) return;
    if (DSHPetDisabledByFlag()) {
        // 用户在安装器 App 里把桌宠关掉了，别建窗口，省电也省心
        DSHTrace(@"start: skipped, disabled flag present");
        return;
    }
    DSHTrace(@"start: enter");
    UIWindowScene *scene = [self findScene];
    DSHTrace(@"start: findScene -> %@", scene ? NSStringFromClass([scene class]) : @"nil");
    if (!scene) {
        if (self.retryCount < 40) {
            self.retryCount++;
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf start];
            });
        } else {
            DSHPET_LOG(@"no window scene found yet; will retry when app becomes active");
        }
        return;
    }
    self.started = YES;
    DSHTrace(@"start: calling buildWithScene");
    [self buildWithScene:scene];
    DSHTrace(@"start: buildWithScene returned");
}

- (void)buildWithScene:(UIWindowScene *)scene {
    DSHTrace(@"build: begin");
    DSHPetWindow *window = [[DSHPetWindow alloc] initWithWindowScene:scene];
    DSHTrace(@"build: window=%@", window);
    if (!window) {
        DSHPET_LOG(@"window creation failed");
        return;
    }
    CGRect bounds = scene.coordinateSpace.bounds;
    DSHTrace(@"build: scene bounds=%@", NSStringFromCGRect(bounds));
    if (CGRectGetWidth(bounds) < 1) bounds = [UIScreen mainScreen].bounds;
    DSHTrace(@"build: screen bounds=%@", NSStringFromCGRect(bounds));
    window.frame = bounds;
    // 必须高过 SpringBoard 的桌面/图标窗口，否则窗口虽然创建了却完全看不见
    window.windowLevel = UIWindowLevelAlert;
    window.backgroundColor = [UIColor clearColor];
    window.hidden = NO;
    self.window = window;
    DSHTrace(@"build: window configured");

    CGFloat size = [self storedSize];
    DSHTrace(@"build: size=%.1f", size);
    DSHPetPetView *view = [[DSHPetPetView alloc] initWithFrame:CGRectZero];
    DSHTrace(@"build: petView created");
    view.frame = [self petRectForSize:size];
    self.petView = view;
    window.petView = view;
    [window addSubview:view];
    DSHTrace(@"build: petView added");

    DSHPetAnimator *animator = [DSHPetAnimator new];
    animator.view = view;
    self.animator = animator;
    DSHTrace(@"build: animator created");

    __weak typeof(self) weakSelf = self;
    view.onEnded = ^(NSString *name) { [weakSelf.animator handleEnded:name]; };
    view.onFrontReady = ^{ [weakSelf.animator handleFrontReady]; };
    view.onTap = ^{
        [DSHPetSpeechBubbleView hide];   // 點一下就把還掛著的對話泡泡收掉
        [weakSelf.animator handleTap];
    };
    view.onLongPress = ^{
        [DSHPetSpeechBubbleView hide];
        [weakSelf.animator cancelDrag];
        [weakSelf showMenu];
    };
    view.onDragBegan = ^(CGPoint p) { [weakSelf.animator beginDragAt:p]; };
    view.onDragMoved = ^(CGPoint p, CGPoint v) { [weakSelf.animator dragMovedTo:p]; };
    view.onDragEnded = ^(CGPoint p, CGPoint v, BOOL dragged) {
        if (dragged) [weakSelf.animator endDragAt:p velocity:v];
    };

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationChanged)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    [animator start];
    DSHTrace(@"build: animator started");
    DSHTrace(@"build: done");
    DSHPET_LOG(@"started, bounds=%@", NSStringFromCGRect(bounds));
}

- (void)stop {
    [self.animator stop];
    // buildWithScene 每次都会注册方向监听，这里必须对应移除，否则反复开关会累积重复回调
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [self.petView removeFromSuperview];
    self.window.hidden = YES;
    self.window = nil;
    self.petView = nil;
    self.animator = nil;
    self.menu = nil;
    self.started = NO;
}

/**
 * 按开关文件的实际状态把桌宠调成开或关。
 * 由 Tweak.xm 注册的 Darwin notification 回调触发，运行在主线程。
 */
- (void)applyToggleState {
    BOOL disabled = DSHPetDisabledByFlag();
    DSHTrace(@"toggle: apply disabled=%d started=%d", (int)disabled, (int)self.started);
    if (disabled) {
        if (self.started) [self stop];
    } else {
        if (!self.started) {
            self.retryCount = 0;
            [self start];
        }
    }
}

#pragma mark - 位置 / 尺寸

- (CGFloat)storedSize {
    CGFloat s = [[NSUserDefaults standardUserDefaults] doubleForKey:kDSHPetSizeKey];
    // 1.2.1 起三档整体放大。老版本存下来的 96/132/180 要映射到新档位，
    // 否则升级后桌宠还停在原来的小尺寸，用户会以为放大没生效。
    if (s == 96.0 || s == 132.0 || s == 180.0) {
        s = (s == 96.0) ? 128.0 : ((s == 132.0) ? 176.0 : 248.0);
        [self saveSize:s];
    }
    if (s < 64 || s > 400) s = 176;
    return s;
}

- (void)saveSize:(CGFloat)size {
    [[NSUserDefaults standardUserDefaults] setDouble:size forKey:kDSHPetSizeKey];
}

- (NSString *)storedCorner {
    NSString *c = [[NSUserDefaults standardUserDefaults] stringForKey:kDSHPetCornerKey];
    if (c.length == 0) c = @"bottom-right";
    return c;
}

- (CGRect)petRectForSize:(CGFloat)size {
    CGRect b = [self screenBounds];
    CGFloat w = size;
    CGFloat h = size * 9.0 / 16.0;
    CGFloat margin = 16.0;
    CGFloat bottomInset = 92.0;
    NSString *corner = [self storedCorner];
    CGFloat x, y;
    if ([corner isEqualToString:@"top-left"]) {
        x = margin;
        y = 96.0;
    } else if ([corner isEqualToString:@"top-right"]) {
        x = CGRectGetWidth(b) - margin - w;
        y = 96.0;
    } else if ([corner isEqualToString:@"bottom-left"]) {
        x = margin;
        y = CGRectGetHeight(b) - bottomInset - h;
    } else {
        x = CGRectGetWidth(b) - margin - w;
        y = CGRectGetHeight(b) - bottomInset - h;
    }
    return CGRectMake(x, y, w, h);
}

- (void)layoutPet {
    if (!self.petView) return;
    CGRect old = self.petView.frame;
    CGRect r = [self petRectForSize:CGRectGetWidth(old)];
    // 如果用户手动拖到别处，保留中心位置，只钳制到屏幕内
    CGRect screen = [self screenBounds];
    r.origin.x = DSHPetClamp(CGRectGetMidX(old) - CGRectGetWidth(r) / 2.0, -12.0, CGRectGetWidth(screen) - CGRectGetWidth(r) + 12.0);
    r.origin.y = DSHPetClamp(CGRectGetMinY(old), 0.0, CGRectGetHeight(screen) - CGRectGetHeight(r));
    self.petView.frame = r;
}

- (void)deviceOrientationChanged {
    if (!self.window || !self.petView) return;
    CGRect b = self.window.windowScene ? self.window.windowScene.coordinateSpace.bounds : [UIScreen mainScreen].bounds;
    if (CGRectGetWidth(b) < 1) b = [UIScreen mainScreen].bounds;
    self.window.frame = b;
    [self layoutPet];
}

- (void)setPetSize:(CGFloat)size {
    if (!self.petView) return;
    CGRect old = self.petView.frame;
    CGFloat cx = CGRectGetMidX(old);
    CGFloat bottom = CGRectGetMaxY(old);
    CGRect r = [self petRectForSize:size];
    r.origin.x = cx - CGRectGetWidth(r) / 2.0;
    r.origin.y = bottom - CGRectGetHeight(r);
    self.petView.frame = r;
    [self saveSize:size];
}

#pragma mark - 菜单

- (void)showMenu {
    if (!self.animator || !self.window) return;
    if (self.menu) return;
    DSHPetMenuView *menu = [[DSHPetMenuView alloc] initWithSleeping:self.animator.sleeping];
    __weak typeof(self) weakSelf = self;
    menu.onAction = ^(DSHPetMenuAction action) {
        [weakSelf handleMenuAction:action];
    };
    menu.onDismiss = ^{
        DSHPetManager *strongSelf = weakSelf;
        strongSelf.menu = nil;
        strongSelf.window.menuView = nil;
    };
    [menu showInWindow:self.window];
    self.menu = menu;
    self.window.menuView = menu;
}

- (void)showChatBubble {
    // 直接掛在桌寵窗口上，不跳 App：這台手機沒網，開 App 也只是多一層。
    if (!self.window) return;
    if (self.window.chatBubbleView) return;   // 已經開著了

    DSHPetChatBubbleView *bubble = [[DSHPetChatBubbleView alloc] initWithFrame:CGRectZero];
    bubble.petAnchor = self.petView;
    __weak typeof(self) weakSelf = self;
    bubble.onDismiss = ^{
        weakSelf.window.chatBubbleView = nil;
    };
    self.window.chatBubbleView = bubble;
    [bubble showInWindow:self.window];
    DSHTrace(@"chat: bubble shown");
}

- (void)handleMenuAction:(DSHPetMenuAction)action {
    switch (action) {
        case DSHPetMenuActionChat:
            [self showChatBubble];
            break;
        case DSHPetMenuActionSleepToggle:
            [self.animator toggleSleep];
            break;
        case DSHPetMenuActionRandomAction:
            [self.animator randomAction];
            break;
        case DSHPetMenuActionHome:
            if (self.petView) self.petView.frame = [self petRectForSize:CGRectGetWidth(self.petView.frame)];
            break;
        case DSHPetMenuActionSizeSmall:
            [self setPetSize:128.0];
            break;
        case DSHPetMenuActionSizeMedium:
            [self setPetSize:176.0];
            break;
        case DSHPetMenuActionSizeLarge:
            [self setPetSize:248.0];
            break;
        case DSHPetMenuActionHide:
            [self hideTemporarily];
            break;
        default:
            break;
    }
}

- (void)hideTemporarily {
    if (!self.window) return;
    self.window.hidden = YES;
    [self.animator stop];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(600ULL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DSHPetManager *strongSelf = weakSelf;
        if (!strongSelf.window) return;
        strongSelf.window.hidden = NO;
        [strongSelf.animator start];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
