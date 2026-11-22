#import "DSHPetPreviewViewController.h"
#import "DSHPetPetView.h"
#import "DSHPetAnimator.h"
#import "DSHPetCommon.h"

@interface DSHPetPreviewViewController ()
@property (nonatomic, strong) DSHPetPetView *petView;
@property (nonatomic, strong) DSHPetAnimator *animator;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIStackView *buttonRow;
@property (nonatomic) BOOL animatorRunning;
@end

@implementation DSHPetPreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"預覽";
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.08 blue:0.13 alpha:1.0];

    NSString *root = DSHPetAssetsRoot();
    BOOL ready = root.length > 0;

    UILabel *hint = [[UILabel alloc] init];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.numberOfLines = 0;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.font = [UIFont systemFontOfSize:13];
    hint.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    hint.text = ready
        ? @"素材讀取自 /var/jb/Library/DSHPet/mov\n單擊打招呼 · 長按打開選單 · 拖著甩會飛出去"
        : @"找不到動畫素材：請先安裝桌寵插件。\n（素材路徑 /var/jb/Library/DSHPet/mov）";
    [self.view addSubview:hint];
    self.hintLabel = hint;

    CGFloat width = 200.0;
    CGFloat height = width * 9.0 / 16.0;
    DSHPetPetView *pet = [[DSHPetPetView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    pet.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 210.0);
    pet.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:pet];
    self.petView = pet;

    DSHPetAnimator *animator = [DSHPetAnimator new];
    animator.view = pet;
    self.animator = animator;

    __weak typeof(self) weakSelf = self;
    pet.onEnded = ^(NSString *name) { [weakSelf.animator handleEnded:name]; };
    pet.onFrontReady = ^{ [weakSelf.animator handleFrontReady]; };
    pet.onTap = ^{ [weakSelf.animator handleTap]; };
    pet.onLongPress = ^{
        [weakSelf.animator cancelDrag];
        [weakSelf.animator randomAction];
        [weakSelf flashHint:@"隨機表演"];
    };
    pet.onDragBegan = ^(CGPoint p) { [weakSelf.animator beginDragAt:p]; };
    pet.onDragMoved = ^(CGPoint p, CGPoint v) { [weakSelf.animator dragMovedTo:p]; };
    pet.onDragEnded = ^(CGPoint p, CGPoint v, BOOL dragged) {
        if (dragged) [weakSelf.animator endDragAt:p velocity:v];
    };

    [self buildButtons];

    [NSLayoutConstraint activateConstraints:@[
        [hint.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [hint.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [hint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];
}

- (void)buildButtons {
    NSArray<NSString *> *titles = @[@"隨機動作", @"睡覺", @"回中間"];
    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
        button.layer.cornerRadius = 18;
        button.tag = i;
        [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:38].active = YES;
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:92].active = YES;
        [buttons addObject:button];
    }

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    row.distribution = UIStackViewDistributionFillEqually;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:row];
    self.buttonRow = row;

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [row.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [row.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];
}

- (void)buttonTapped:(UIButton *)sender {
    if (sender.tag == 0) {
        [self.animator randomAction];
        [self flashHint:@"隨機表演"];
    } else if (sender.tag == 1) {
        [self.animator toggleSleep];
        [self flashHint:self.animator.sleeping ? @"睡著了…" : @"醒來了"];
    } else {
        [self.animator cancelDrag];
        CGFloat width = 200.0;
        CGFloat height = width * 9.0 / 16.0;
        self.petView.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - width) / 2.0,
                                        CGRectGetMaxY(self.view.bounds) - 210.0 - height / 2.0,
                                        width, height);
    }
}

- (void)flashHint:(NSString *)text {
    NSString *base = @"素材讀取自 /var/jb/Library/DSHPet/mov\n單擊打招呼 · 長按打開選單 · 拖著甩會飛出去";
    self.hintLabel.text = [NSString stringWithFormat:@"%@\n%@", base, text];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restoreHint) object:nil];
    [self performSelector:@selector(restoreHint) withObject:nil afterDelay:1.6];
}

- (void)restoreHint {
    self.hintLabel.text = @"素材讀取自 /var/jb/Library/DSHPet/mov\n單擊打招呼 · 長按打開選單 · 拖著甩會飛出去";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.animatorRunning || DSHPetAssetsRoot().length == 0) return;
    self.animatorRunning = YES;
    [self.animator start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.animatorRunning) return;
    self.animatorRunning = NO;
    [self.animator stop];
    [self.petView disposePlayers];
}

@end
