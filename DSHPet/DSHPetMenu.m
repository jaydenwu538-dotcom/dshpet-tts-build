#import "DSHPetMenu.h"

@interface DSHPetMenuView ()
@property (nonatomic, strong) UIView *panel;
@property (nonatomic) BOOL dismissing;
@end

@implementation DSHPetMenuView

- (instancetype)initWithSleeping:(BOOL)sleeping {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self buildWithSleeping:sleeping];
    }
    return self;
}

- (UIButton *)makeButton:(NSString *)title tag:(DSHPetMenuAction)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    b.layer.cornerRadius = 10;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    b.tag = tag;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b.heightAnchor constraintEqualToConstant:42].active = YES;
    [b addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)buildWithSleeping:(BOOL)sleeping {
    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.panel.translatesAutoresizingMaskIntoConstraints = NO;
    self.panel.backgroundColor = [UIColor colorWithWhite:0.11 alpha:0.94];
    self.panel.layer.cornerRadius = 18;
    self.panel.layer.cornerCurve = kCACornerCurveContinuous;
    self.panel.layer.borderWidth = 0.5;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    [self addSubview:self.panel];

    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:stack];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = @"DSH Pet";
    title.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    title.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:title];

    UIButton *sleepBtn = [self makeButton:(sleeping ? @"叫醒它" : @"让它睡觉") tag:DSHPetMenuActionSleepToggle];
    [stack addArrangedSubview:sleepBtn];
    [stack addArrangedSubview:[self makeButton:@"聊聊天" tag:DSHPetMenuActionChat]];
    [stack addArrangedSubview:[self makeButton:@"随机表演" tag:DSHPetMenuActionRandomAction]];
    [stack addArrangedSubview:[self makeButton:@"回到角落" tag:DSHPetMenuActionHome]];

    UILabel *sizeTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    sizeTitle.text = @"大小";
    sizeTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    sizeTitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    sizeTitle.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:sizeTitle];

    UIStackView *sizes = [[UIStackView alloc] initWithFrame:CGRectZero];
    sizes.axis = UILayoutConstraintAxisHorizontal;
    sizes.spacing = 8;
    sizes.distribution = UIStackViewDistributionFillEqually;
    UIButton *s = [self makeButton:@"小" tag:DSHPetMenuActionSizeSmall];
    UIButton *m = [self makeButton:@"中" tag:DSHPetMenuActionSizeMedium];
    UIButton *l = [self makeButton:@"大" tag:DSHPetMenuActionSizeLarge];
    [sizes addArrangedSubview:s];
    [sizes addArrangedSubview:m];
    [sizes addArrangedSubview:l];
    [stack addArrangedSubview:sizes];

    [stack addArrangedSubview:[self makeButton:@"隐藏 10 分钟" tag:DSHPetMenuActionHide]];

    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectZero];
    footer.text = @"长按宠物再次打开菜单";
    footer.textColor = [UIColor colorWithWhite:1.0 alpha:0.35];
    footer.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
    footer.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:footer];

    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
    bgTap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:bgTap];

    [NSLayoutConstraint activateConstraints:@[
        [self.panel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.panel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.panel.widthAnchor constraintEqualToConstant:264],
        [stack.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-14],
    ]];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:self];
    if (!CGRectContainsPoint(self.panel.frame, p)) [self dismiss];
}

- (void)buttonTapped:(UIButton *)sender {
    DSHPetMenuAction action = (DSHPetMenuAction)sender.tag;
    void (^cb)(DSHPetMenuAction) = self.onAction;
    [self dismiss];
    if (cb) cb(action);
}

- (void)showInWindow:(UIWindow *)window {
    self.frame = window.bounds;
    [window addSubview:self];
    [self layoutIfNeeded];
    self.alpha = 0.0;
    self.panel.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 1.0;
        self.panel.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    if (self.dismissing) return;
    self.dismissing = YES;
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 0.0;
        self.panel.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onDismiss) self.onDismiss();
    }];
}

@end
