#import "DSHPetSpeechBubble.h"

static const CGFloat kDSHBubbleMaxWidth = 260.0;
static const CGFloat kDSHBubblePaddingX = 14.0;
static const CGFloat kDSHBubblePaddingY = 10.0;
static const CGFloat kDSHBubbleTailWidth = 16.0;
static const CGFloat kDSHBubbleTailHeight = 9.0;
static const CGFloat kDSHBubbleCorner = 13.0;

static DSHPetSpeechBubbleView *gCurrentBubble = nil;

@interface DSHPetSpeechBubbleView ()
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) CAShapeLayer *bgLayer;
@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic) CGSize lastLaidOutSize;
@end

@implementation DSHPetSpeechBubbleView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;

        self.bgLayer = [CAShapeLayer layer];
        self.bgLayer.fillColor = [UIColor colorWithWhite:1.0 alpha:0.97].CGColor;
        self.bgLayer.shadowColor = [UIColor blackColor].CGColor;
        self.bgLayer.shadowOpacity = 0.16;
        self.bgLayer.shadowRadius = 6;
        self.bgLayer.shadowOffset = CGSizeMake(0, 2);
        [self.layer addSublayer:self.bgLayer];

        self.label = [[UILabel alloc] initWithFrame:CGRectZero];
        self.label.numberOfLines = 0;
        self.label.textColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        self.label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [self addSubview:self.label];
    }
    return self;
}

// 圆角矩形 + 底部居中的小三角，一起做成一条 path。
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    if (CGSizeEqualToSize(size, self.lastLaidOutSize)) return;
    self.lastLaidOutSize = size;

    CGRect body = CGRectMake(0, 0, size.width, size.height - kDSHBubbleTailHeight);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:kDSHBubbleCorner];

    CGFloat tailX = CGRectGetMidX(body);
    UIBezierPath *tail = [UIBezierPath bezierPath];
    [tail moveToPoint:CGPointMake(tailX - kDSHBubbleTailWidth / 2.0, CGRectGetMaxY(body) - 1.0)];
    [tail addLineToPoint:CGPointMake(tailX, size.height)];
    [tail addLineToPoint:CGPointMake(tailX + kDSHBubbleTailWidth / 2.0, CGRectGetMaxY(body) - 1.0)];
    [tail closePath];
    [path appendPath:tail];

    self.bgLayer.frame = self.bounds;
    self.bgLayer.path = path.CGPath;
    self.bgLayer.shadowPath = path.CGPath;

    self.label.frame = CGRectMake(kDSHBubblePaddingX,
                                  kDSHBubblePaddingY,
                                  size.width - kDSHBubblePaddingX * 2.0,
                                  size.height - kDSHBubbleTailHeight - kDSHBubblePaddingY * 2.0);
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize maxLabel = CGSizeMake(kDSHBubbleMaxWidth - kDSHBubblePaddingX * 2.0, CGFLOAT_MAX);
    CGSize labelSize = [self.label sizeThatFits:maxLabel];
    return CGSizeMake(ceil(labelSize.width) + kDSHBubblePaddingX * 2.0,
                      ceil(labelSize.height) + kDSHBubblePaddingY * 2.0 + kDSHBubbleTailHeight);
}

#pragma mark - public

+ (void)showText:(NSString *)text aboveView:(UIView *)anchor inWindow:(UIWindow *)window {
    if (![text length] || !window) return;
    // 這裡沒有 @synchronized：所有調用都在主線程（動畫回調與推理 completion 都切回 main）。
    [self hide];

    DSHPetSpeechBubbleView *bubble = [[DSHPetSpeechBubbleView alloc] initWithFrame:CGRectZero];
    bubble.label.text = text;

    CGSize size = [bubble sizeThatFits:CGSizeMake(kDSHBubbleMaxWidth, CGFLOAT_MAX)];
    size.width = MIN(size.width, kDSHBubbleMaxWidth);

    CGSize winSize = window.bounds.size;
    CGFloat anchorMidX = anchor ? CGRectGetMidX(anchor.frame) : winSize.width / 2.0;
    CGFloat anchorTop = anchor ? CGRectGetMinY(anchor.frame) : winSize.height / 2.0;

    CGFloat x = anchorMidX - size.width / 2.0;
    x = MAX(8.0, MIN(x, winSize.width - size.width - 8.0));
    CGFloat y = anchorTop - size.height - 6.0;
    y = MAX(8.0, y);

    bubble.frame = CGRectMake(x, y, size.width, size.height);
    [window addSubview:bubble];

    gCurrentBubble = bubble;

    bubble.alpha = 0.0;
    bubble.transform = CGAffineTransformMakeScale(0.88, 0.88);
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        bubble.alpha = 1.0;
        bubble.transform = CGAffineTransformIdentity;
    } completion:nil];

    // 文字越長留越久，但最多 12 秒，免得一直掛在桌面上。
    NSTimeInterval alive = MIN(12.0, 3.0 + [text length] * 0.09);
    bubble.hideTimer = [NSTimer scheduledTimerWithTimeInterval:alive repeats:NO block:^(NSTimer *timer) {
        [self hide];
    }];
}

+ (void)hide {
    DSHPetSpeechBubbleView *bubble = gCurrentBubble;
    if (!bubble) return;
    gCurrentBubble = nil;
    [bubble.hideTimer invalidate];
    bubble.hideTimer = nil;

    [UIView animateWithDuration:0.16 animations:^{
        bubble.alpha = 0.0;
        bubble.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        [bubble removeFromSuperview];
    }];
}

@end
