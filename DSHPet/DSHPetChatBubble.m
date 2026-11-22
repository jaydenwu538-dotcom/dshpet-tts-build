#import "DSHPetChatBubble.h"
#import "DSHPetChat.h"
#import "DSHPetSpeechBubble.h"
#import "DSHPetVoice.h"

@interface DSHPetChatBubbleView () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *replyLabel;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *voiceButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic) BOOL thinking;
@property (nonatomic) BOOL dismissing;
@property (nonatomic, weak) NSLayoutConstraint *panelBottom;
@end

@implementation DSHPetChatBubbleView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.001];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.panel.translatesAutoresizingMaskIntoConstraints = NO;
    self.panel.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
    self.panel.layer.cornerRadius = 18;
    self.panel.layer.cornerCurve = kCACornerCurveContinuous;
    self.panel.layer.borderWidth = 0.5;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
    [self addSubview:self.panel];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = @"聊兩句";
    title.textColor = [UIColor colorWithWhite:1.0 alpha:0.90];
    title.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    close.tintColor = [UIColor colorWithWhite:1.0 alpha:0.35];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:close];

    self.voiceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.voiceButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.voiceButton addTarget:self action:@selector(voiceTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.voiceButton];

    self.replyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.replyLabel.text = @"想聊什麼？打一句就好，完全離線。";
    self.replyLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    self.replyLabel.font = [UIFont systemFontOfSize:15];
    self.replyLabel.numberOfLines = 0;
    self.replyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:self.replyLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor colorWithWhite:1.0 alpha:0.65];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:self.spinner];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
    bar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    bar.layer.cornerRadius = 12;
    bar.layer.cornerCurve = kCACornerCurveContinuous;
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:bar];

    self.field = [[UITextField alloc] initWithFrame:CGRectZero];
    self.field.placeholder = @"說點什麼…";
    self.field.textColor = [UIColor whiteColor];
    self.field.tintColor = [UIColor colorWithRed:0.35 green:0.72 blue:1.0 alpha:1.0];
    self.field.font = [UIFont systemFontOfSize:15];
    self.field.returnKeyType = UIReturnKeySend;
    self.field.delegate = self;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:self.field];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setImage:[UIImage systemImageNamed:@"arrow.up.circle.fill"] forState:UIControlStateNormal];
    self.sendButton.tintColor = [UIColor colorWithRed:0.35 green:0.72 blue:1.0 alpha:1.0];
    self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.sendButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.panel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.panel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.panel.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:80],

        [title.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:14],
        [title.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:16],

        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [close.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-14],
        [close.widthAnchor constraintEqualToConstant:26],
        [close.heightAnchor constraintEqualToConstant:26],

        [self.voiceButton.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.voiceButton.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-10],
        [self.voiceButton.widthAnchor constraintEqualToConstant:26],
        [self.voiceButton.heightAnchor constraintEqualToConstant:26],

        [self.replyLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [self.replyLabel.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:16],
        [self.replyLabel.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-16],

        [self.spinner.centerYAnchor constraintEqualToAnchor:self.replyLabel.centerYAnchor],
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.replyLabel.trailingAnchor],

        [bar.topAnchor constraintEqualToAnchor:self.replyLabel.bottomAnchor constant:14],
        [bar.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:12],
        [bar.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-12],
        [bar.heightAnchor constraintEqualToConstant:44],
        [bar.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-12],

        [self.field.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:12],
        [self.field.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.field.trailingAnchor constraintEqualToAnchor:self.sendButton.leadingAnchor constant:-8],

        [self.sendButton.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8],
        [self.sendButton.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.sendButton.widthAnchor constraintEqualToConstant:32],
        [self.sendButton.heightAnchor constraintEqualToConstant:32],
    ]];

    // 面板貼著鍵盤上緣（iOS 15+ 的 keyboardLayoutGuide，不用自己算高度）。
    self.panelBottom = [self.panel.bottomAnchor constraintEqualToAnchor:self.keyboardLayoutGuide.topAnchor constant:-12];
    self.panelBottom.active = YES;

    [self.field addTarget:self action:@selector(fieldChanged) forControlEvents:UIControlEventEditingChanged];
    [self updateVoiceIcon];
}

- (void)updateVoiceIcon {
    BOOL on = [DSHPetVoice enabled];
    NSString *name = on ? @"speaker.wave.2.fill" : @"speaker.slash.fill";
    [self.voiceButton setImage:[UIImage systemImageNamed:name] forState:UIControlStateNormal];
    self.voiceButton.tintColor = on
        ? [UIColor colorWithRed:0.35 green:0.72 blue:1.0 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.35];
}

- (void)voiceTapped {
    BOOL on = ![DSHPetVoice enabled];
    [DSHPetVoice setEnabled:on];
    if (!on) [DSHPetVoice stop];
    [self updateVoiceIcon];
}

- (void)showInWindow:(UIWindow *)window {
    self.frame = window.bounds;
    [window addSubview:self];

    self.alpha = 0.0;
    self.panel.transform = CGAffineTransformMakeTranslation(0, 14);
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 1.0;
        self.panel.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [self.field becomeFirstResponder];
    }];
}

- (void)closeTapped {
    [self.field resignFirstResponder];
    [self dismiss];
}

- (void)dismiss {
    if (self.dismissing) return;
    self.dismissing = YES;
    [UIView animateWithDuration:0.16 animations:^{
        self.alpha = 0.0;
        self.panel.transform = CGAffineTransformMakeTranslation(0, 10);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onDismiss) self.onDismiss();
    }];
}

- (void)fieldChanged {
    self.sendButton.enabled = [[self.field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0 && !self.thinking;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendTapped];
    return NO;
}

- (void)setThinking:(BOOL)thinking {
    _thinking = thinking;
    self.sendButton.enabled = !thinking;
    self.field.enabled = !thinking;
    if (thinking) [self.spinner startAnimating];
    else [self.spinner stopAnimating];
}

- (void)sendTapped {
    if (self.thinking) return;
    NSString *text = [self.field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![text length]) return;

    NSString *reason = [DSHPetChat unavailableReason];
    if (reason) {
        self.replyLabel.text = reason;
        return;
    }

    self.field.text = @"";
    self.replyLabel.text = @"…";
    self.thinking = YES;

    __weak typeof(self) weakSelf = self;
    [DSHPetChat ask:text completion:^(NSString *reply, NSString *error) {
        DSHPetChatBubbleView *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.thinking = NO;
        if ([error length]) {
            strongSelf.replyLabel.text = error;
            return;
        }
        // 成功就收起輸入面板，答案改成寵物頭頂的漫畫氣泡。
        UIWindow *win = strongSelf.window;
        UIView *anchor = strongSelf.petAnchor;
        [strongSelf.field resignFirstResponder];
        [strongSelf dismiss];
        [DSHPetSpeechBubbleView showText:reply aboveView:anchor inWindow:win];
        // 先出字、再出声：模型把整段话生成完了，气泡已经贴在宠物头顶，这时才开始念，
        // 用户不会盯着一个空面板听声音。
        [DSHPetVoice speak:reply];
    }];
}

@end
