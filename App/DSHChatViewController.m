//
//  DSHChatViewController.m
//  DSHPet 安裝器
//
//  極簡對話頁：上面是氣泡列表，下面是輸入欄；右上角齒輪進去填介面地址 / 模型 / Key。
//  手機常態離線，所以連不上網時只提示「開 WiFi」，不做重試隊列。
//

#import "DSHChatViewController.h"
#import "DSHChat.h"

#pragma mark - 气泡 Cell

@interface DSHChatBubbleCell : UITableViewCell
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *bubbleLabel;
@property (nonatomic, strong) NSLayoutConstraint *leftConstraint;
@property (nonatomic, strong) NSLayoutConstraint *rightConstraint;
- (void)configureWithText:(NSString *)text isUser:(BOOL)isUser;
@end

@implementation DSHChatBubbleCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _bubbleView = [UIView new];
    _bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    _bubbleView.layer.cornerRadius = 16.0;
    _bubbleView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.contentView addSubview:_bubbleView];

    _bubbleLabel = [UILabel new];
    _bubbleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bubbleLabel.numberOfLines = 0;
    _bubbleLabel.font = [UIFont systemFontOfSize:15.0];
    [_bubbleView addSubview:_bubbleLabel];

    // 气泡最宽只占 78%，留出边距看得出来是聊天气泡
    _leftConstraint = [_bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14.0];
    _rightConstraint = [_bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0];

    [NSLayoutConstraint activateConstraints:@[
        [_bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
        [_bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],
        [_bubbleView.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor multiplier:0.78],
        [_bubbleLabel.topAnchor constraintEqualToAnchor:_bubbleView.topAnchor constant:9.0],
        [_bubbleLabel.bottomAnchor constraintEqualToAnchor:_bubbleView.bottomAnchor constant:-9.0],
        [_bubbleLabel.leadingAnchor constraintEqualToAnchor:_bubbleView.leadingAnchor constant:13.0],
        [_bubbleLabel.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor constant:-13.0],
    ]];

    return self;
}

- (void)configureWithText:(NSString *)text isUser:(BOOL)isUser {
    self.bubbleLabel.text = text;
    if (isUser) {
        _leftConstraint.active = NO;
        _rightConstraint.active = YES;
        _bubbleView.backgroundColor = [UIColor colorWithRed:0.12 green:0.45 blue:0.95 alpha:1.0];
        _bubbleLabel.textColor = [UIColor whiteColor];
        _bubbleLabel.textAlignment = NSTextAlignmentNatural;
    } else {
        _rightConstraint.active = NO;
        _leftConstraint.active = YES;
        _bubbleView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        _bubbleLabel.textColor = [UIColor labelColor];
        _bubbleLabel.textAlignment = NSTextAlignmentNatural;
    }
}

@end


#pragma mark - 设置页

@interface DSHChatSettingsViewController : UITableViewController
@end

@implementation DSHChatSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"對話設定";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"推理方式";
    if (section == 1) return @"本地模型（離線）";
    if (section == 2) return @"API（備用，要連網）";
    return @"其他";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"本地模型跑在手機上，不需要網路也不需要 API Key；API 模式要能連外網，而且你的介面位址目前可能被地區限制。";
    }
    if (section == 1) {
        return @"執行檔與模型都由 deb 一起安裝。想換模型就把 .gguf 拷到手機，再把下面的路徑指過去。";
    }
    if (section == 2) {
        return @"介面位址填到 /v1 為止，例如 https://api.openai.com/v1。\n"
               @"Key 存在 /var/mobile/Documents 下單獨一個檔案裡（權限 0600），不寫進偏好設定。";
    }
    return @"提示詞決定牠說話的口氣，越短越省 token。";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;   // 本地 / API 開關
    if (section == 1) return 2;   // 狀態 / 模型路徑
    if (section == 2) return 3;   // 介面地址 / 模型 / API Key
    return 2;                     // 人格提示詞 / 還原預設
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    cell.textLabel.font = [UIFont systemFontOfSize:16.0];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    if (indexPath.section == 0) {
        cell.textLabel.text = @"本地模型";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = ([DSHChat backend] == DSHChatBackendLocal);
        [sw addTarget:self action:@selector(backendChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.detailTextLabel.text = sw.on ? @"現在跑本地模型，離線也能聊" : @"現在用 API，需要網路";
        return cell;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            BOOL ok = [DSHChat localBinaryAvailable] && [DSHChat localModelAvailable];
            cell.textLabel.text = @"狀態";
            cell.detailTextLabel.text = [DSHChat localStatusText];
            cell.textLabel.textColor = ok ? [UIColor labelColor] : [UIColor systemOrangeColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"模型路徑";
            cell.detailTextLabel.text = [DSHChat localModelPath];
            cell.detailTextLabel.numberOfLines = 3;
        }
        return cell;
    }

    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"介面地址";
            cell.detailTextLabel.text = [DSHChat baseURLString];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"模型";
            cell.detailTextLabel.text = [DSHChat modelName];
        } else {
            cell.textLabel.text = @"API Key";
            cell.detailTextLabel.text = [DSHChat hasAPIKey] ? @"已設定（點一下可以改或清除）" : @"尚未設定";
            cell.textLabel.textColor = [DSHChat hasAPIKey] ? [UIColor labelColor] : [UIColor systemOrangeColor];
        }
        return cell;
    }

    if (indexPath.row == 0) {
        cell.textLabel.text = @"人格提示詞";
        cell.detailTextLabel.text = [DSHChat systemPrompt];
    } else {
        cell.textLabel.text = @"還原預設設定";
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.detailTextLabel.text = nil;
    }
    return cell;
}

- (void)backendChanged:(UISwitch *)sender {
    [DSHChat setBackend:sender.on ? DSHChatBackendLocal : DSHChatBackendAPI];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) return;   // 開關自己處理

    if (indexPath.section == 1) {
        if (indexPath.row == 0) return;
        [self promptWithTitle:@"模型路徑"
                      current:[DSHChat localModelPath]
                   isSecret:NO
                      apply:^(NSString *value) {
            [DSHChat setLocalModelPath:value];
            [self.tableView reloadData];
        }];
        return;
    }

    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self promptWithTitle:@"介面地址"
                          current:[DSHChat baseURLString]
                       isSecret:NO
                          apply:^(NSString *value) {
                [DSHChat setBaseURLString:value];
                [self.tableView reloadData];
            }];
        } else if (indexPath.row == 1) {
            [self promptWithTitle:@"模型"
                          current:[DSHChat modelName]
                       isSecret:NO
                          apply:^(NSString *value) {
                [DSHChat setModelName:value];
                [self.tableView reloadData];
            }];
        } else {
            [self promptWithTitle:@"API Key"
                          current:nil
                       isSecret:YES
                          apply:^(NSString *value) {
                [DSHChat setAPIKey:value];
                [self.tableView reloadData];
            }];
        }
        return;
    }

    if (indexPath.row == 1) {
        [DSHChat setBaseURLString:@"https://api.deepseek.com"];
        [DSHChat setModelName:@"deepseek-chat"];
        [DSHChat setSystemPrompt:@""];
        [DSHChat setAPIKey:nil];
        [DSHChat setLocalModelPath:nil];
        [DSHChat setBackend:DSHChatBackendLocal];
        [self.tableView reloadData];
        return;
    }

    [self promptWithTitle:@"人格提示詞"
                  current:[DSHChat systemPrompt]
               isSecret:NO
                  apply:^(NSString *value) {
        [DSHChat setSystemPrompt:value];
        [self.tableView reloadData];
    }];
}

// 統一用 alert 收一個字串：設置項就這幾個，做一頁專門的表單反而更繞
- (void)promptWithTitle:(NSString *)title
                current:(NSString *)current
               isSecret:(BOOL)isSecret
                  apply:(void (^)(NSString *value))apply {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = current;
        tf.secureTextEntry = isSecret;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *value = alert.textFields.firstObject.text;
        apply(value ?: @"");
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end


#pragma mark - 聊天页

@interface DSHChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableArray<DSHChatMessage *> *messages;
@property (nonatomic, assign) BOOL sending;
@end

@implementation DSHChatViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _messages = [NSMutableArray array];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"對話";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(settingsTapped)];

    [self buildTableView];
    [self buildInputBar];
    [self buildHintIfEmpty];
}

- (void)buildTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 60.0;
    _tableView.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)buildInputBar {
    _inputBar = [UIView new];
    _inputBar.translatesAutoresizingMaskIntoConstraints = NO;
    _inputBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.view addSubview:_inputBar];

    _textField = [UITextField new];
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    _textField.placeholder = @"說點什麼…";
    _textField.borderStyle = UITextBorderStyleRoundedRect;
    _textField.delegate = self;
    _textField.returnKeyType = UIReturnKeySend;
    _textField.enablesReturnKeyAutomatically = YES;
    _textField.font = [UIFont systemFontOfSize:15.0];
    [_inputBar addSubview:_textField];

    _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sendButton setImage:[UIImage systemImageNamed:@"arrow.up.circle.fill"] forState:UIControlStateNormal];
    _sendButton.tintColor = [UIColor systemBlueColor];
    [_sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [_inputBar addSubview:_sendButton];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [_inputBar addSubview:_spinner];

    // iOS 15 的 keyboardLayoutGuide：键盘弹出/收起自动跟着走，不用自己算高度
    [NSLayoutConstraint activateConstraints:@[
        [_inputBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_inputBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_inputBar.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],

        [_textField.topAnchor constraintEqualToAnchor:_inputBar.topAnchor constant:8.0],
        [_textField.bottomAnchor constraintEqualToAnchor:_inputBar.bottomAnchor constant:-8.0],
        [_textField.leadingAnchor constraintEqualToAnchor:_inputBar.leadingAnchor constant:12.0],
        [_textField.heightAnchor constraintEqualToConstant:36.0],

        [_sendButton.leadingAnchor constraintEqualToAnchor:_textField.trailingAnchor constant:8.0],
        [_sendButton.trailingAnchor constraintEqualToAnchor:_inputBar.trailingAnchor constant:-12.0],
        [_sendButton.centerYAnchor constraintEqualToAnchor:_textField.centerYAnchor],
        [_sendButton.widthAnchor constraintEqualToConstant:34.0],
        [_sendButton.heightAnchor constraintEqualToConstant:34.0],

        [_tableView.bottomAnchor constraintEqualToAnchor:_inputBar.topAnchor],

        [_spinner.trailingAnchor constraintEqualToAnchor:_sendButton.leadingAnchor constant:-6.0],
        [_spinner.centerYAnchor constraintEqualToAnchor:_textField.centerYAnchor],
    ]];
}

// 没配置好之前先把用法写在空列表位置上，省得用户点半天没反应
- (void)buildHintIfEmpty {
    UILabel *hint = [UILabel new];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.numberOfLines = 0;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.font = [UIFont systemFontOfSize:13.0];
    hint.textColor = [UIColor tertiaryLabelColor];
    hint.text = @"本地模型是現成的，不用網路，直接打一句就會回。\n"
                 @"想用 API 就點右上角齒輪切過去，那邊才需要 WiFi 和 Key。";
    [self.view addSubview:hint];
    [NSLayoutConstraint activateConstraints:@[
        [hint.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [hint.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [hint.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [hint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0],
    ]];
    hint.tag = 9001;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 从设置页回来时把提示语撤掉
    for (UIView *v in self.view.subviews) {
        if (v.tag == 9001) {
            BOOL ready;
            if ([DSHChat backend] == DSHChatBackendLocal) {
                ready = [DSHChat localBinaryAvailable] && [DSHChat localModelAvailable];
            } else {
                ready = [DSHChat isConfigured];
            }
            v.hidden = ready;
        }
    }
}

- (void)settingsTapped {
    [self.navigationController pushViewController:[DSHChatSettingsViewController new] animated:YES];
}

#pragma mark - 发送

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendTapped];
    return NO;
}

- (void)sendTapped {
    if (self.sending) return;

    NSString *text = [self.textField.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;

    BOOL local = ([DSHChat backend] == DSHChatBackendLocal);

    if (local) {
        if (![DSHChat localBinaryAvailable] || ![DSHChat localModelAvailable]) {
            [self alert:@"本地模型還沒就緒"
                message:[NSString stringWithFormat:@"%@\n\n點右上角齒輪看「本地模型」那一段。執行檔和模型都由 deb 一起安裝，重裝一次插件本體就會補齊。", [DSHChat localStatusText]]];
            return;
        }
    } else if (![DSHChat isConfigured]) {
        [self alert:@"還沒設定好" message:@"右上角齒輪裡把介面地址和 API Key 填上再聊。"];
        return;
    }

    [self.messages addObject:[DSHChatMessage user:text]];
    self.textField.text = @"";
    [self reloadAndScrollBottom];
    [self setSending:YES];

    __weak typeof(self) weakSelf = self;
    void (^done)(NSString *, NSString *) = ^(NSString *reply, NSString *error) {
        typeof(self) self2 = weakSelf;
        if (!self2) return;
        [self2 setSending:NO];
        if (reply.length) {
            [self2.messages addObject:[DSHChatMessage assistant:reply]];
            [self2 reloadAndScrollBottom];
        } else {
            [self2 alert:@"沒有回覆" message:error ?: @"未知錯誤"];
        }
    };

    if (local) {
        // 本地模型一次只吃一輪，把最近幾輪拼成前情提要一起餵進去，聊起來才不會斷片
        NSMutableString *prompt = [NSMutableString string];
        NSUInteger from = self.messages.count > 6 ? self.messages.count - 6 : 0;
        for (NSUInteger i = from; i + 1 < self.messages.count; i++) {
            DSHChatMessage *m = self.messages[i];
            [prompt appendFormat:@"%@：%@\n", (m.role == DSHChatRoleUser) ? @"用戶" : @"助手", m.text];
        }
        [prompt appendFormat:@"用戶：%@\n", text];
        [DSHChat sendLocalMessage:prompt completion:done];
        return;
    }

    // 只帶最近 12 條，避免越聊越貴
    NSUInteger start = self.messages.count > 12 ? self.messages.count - 12 : 0;
    NSArray<DSHChatMessage *> *slice = [self.messages subarrayWithRange:NSMakeRange(start, self.messages.count - start)];
    [DSHChat sendMessages:slice completion:done];
}

- (void)setSending:(BOOL)sending {
    _sending = sending;
    self.sendButton.enabled = !sending;
    self.textField.enabled = !sending;
    if (sending) [self.spinner startAnimating];
    else [self.spinner stopAnimating];
}

- (void)reloadAndScrollBottom {
    [self.tableView reloadData];
    NSUInteger n = self.messages.count;
    if (!n) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *last = [NSIndexPath indexPathForRow:(NSInteger)n - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    });
}

#pragma mark - 表格

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSHChatMessage *m = self.messages[(NSUInteger)indexPath.row];
    BOOL isUser = (m.role == DSHChatRoleUser);
    NSString *reuseId = isUser ? @"user" : @"assistant";
    DSHChatBubbleCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
    if (!cell) cell = [[DSHChatBubbleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseId];
    [cell configureWithText:m.text isUser:isUser];
    return cell;
}

#pragma mark - 小工具

- (void)alert:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
