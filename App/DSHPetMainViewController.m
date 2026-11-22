#import "DSHPetMainViewController.h"
#import "DSHPetDiagnostics.h"
#import "DSHPetPreviewViewController.h"
#import "DSHSecurityViewController.h"
#import "DSHChatViewController.h"
#import "DSHSystemViewController.h"

// 「操作」区行号：第 0 行是桌宠开关（UISwitch），不参与点击动作
static const NSInteger kDSHRowToggle = 0;
static const NSInteger kDSHRowInstall = 1;
static const NSInteger kDSHRowRespring = 2;
static const NSInteger kDSHRowPreview = 3;

@interface DSHTextViewController : UIViewController
@property (nonatomic, copy) NSString *heading;
@property (nonatomic, copy) NSString *body;
+ (instancetype)heading:(NSString *)heading body:(NSString *)body;
@end

@implementation DSHTextViewController

+ (instancetype)heading:(NSString *)heading body:(NSString *)body {
    DSHTextViewController *vc = [DSHTextViewController new];
    vc.heading = heading;
    vc.body = body;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.heading;
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UITextView *textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.editable = NO;
    textView.textContainerInset = UIEdgeInsetsMake(18, 16, 28, 16);
    textView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    textView.textColor = [UIColor labelColor];
    textView.backgroundColor = [UIColor clearColor];
    textView.text = self.body;
    [self.view addSubview:textView];
}

@end

@interface DSHPetMainViewController () <UIDocumentInteractionControllerDelegate>
@property (nonatomic, strong) NSArray<DSHStatusItem *> *statusItems;
@property (nonatomic, strong) UIDocumentInteractionController *docController;
@property (nonatomic, strong) UIAlertController *busyAlert;
@end

@implementation DSHPetMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DSH 桌寵";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.statusItems = @[];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (void)refresh {
    self.statusItems = [DSHPetDiagnostics statusItems];
    [UIView performWithoutAnimation:^{
        [self.tableView reloadData];
    }];
}

#pragma mark - 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"狀態";
    if (section == 1) return @"操作";
    return @"其他";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && ![DSHPetDiagnostics hasJailbreakAccess]) {
        return @"目前讀不到 /var/jb：請確認本 App 是用 TrollStore 安裝的（其他方式會被沙盒限制）。";
    }
    if (section == 1) {
        return @"「桌面顯示」開關是即時的，滑動後桌寵立刻出現或消失，不需要重啟。"
                "下面的安裝走 Sileo，裝完會自動重啟 SpringBoard。";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.statusItems.count;
    if (section == 1) return 4;
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && indexPath.row == kDSHRowToggle) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"toggle"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *toggle = [[UISwitch alloc] init];
            [toggle addTarget:self
                       action:@selector(toggleChanged:)
             forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            cell.imageView.image = [UIImage systemImageNamed:@"pawprint.fill"];
            cell.imageView.tintColor = [UIColor systemPurpleColor];
        }
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.on = [DSHPetDiagnostics petEnabled];
        cell.textLabel.text = @"桌面顯示";
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.text = @"關掉後桌寵立刻消失，不用卸載、不用重啟";
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        return cell;
    }

    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"status"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"status"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.detailTextLabel.numberOfLines = 0;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        }
        DSHStatusItem *item = self.statusItems[indexPath.row];
        cell.textLabel.text = item.title;
        NSString *detail = item.value;
        if (item.note.length > 0) detail = [detail stringByAppendingFormat:@"\n%@", item.note];
        cell.detailTextLabel.text = detail;
        cell.imageView.image = [self iconForState:item.state];
        cell.imageView.tintColor = [self colorForState:item.state];
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"action"];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.numberOfLines = 0;
    }
    cell.textLabel.textColor = [UIColor linkColor];
    cell.detailTextLabel.text = nil;

    if (indexPath.section == 1) {
        if (indexPath.row == kDSHRowInstall) {
            cell.textLabel.text = @"安裝 / 重裝桌寵";
            cell.detailTextLabel.text = @"把內建的 deb 交給 Sileo；裝完會自動重啟 SpringBoard";
            cell.imageView.image = [UIImage systemImageNamed:@"arrow.down.circle"];
            cell.imageView.tintColor = [UIColor linkColor];
        } else if (indexPath.row == kDSHRowRespring) {
            cell.textLabel.text = @"重啟 SpringBoard";
            cell.detailTextLabel.text = @"讓已安裝的插件立即生效";
            cell.imageView.image = [UIImage systemImageNamed:@"power"];
            cell.imageView.tintColor = [UIColor systemOrangeColor];
        } else {
            cell.textLabel.text = @"預覽桌寵";
            cell.detailTextLabel.text = @"直接讀取 /var/jb 內的素材，確認動畫正常";
            cell.imageView.image = [UIImage systemImageNamed:@"play.circle"];
            cell.imageView.tintColor = [UIColor systemGreenColor];
        }
    } else {
        cell.detailTextLabel.text = nil;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"對話";
            cell.detailTextLabel.text = @"本地跑 0.5B 小模型，完全離線；也能切成 API";
            cell.imageView.image = [UIImage systemImageNamed:@"bubble.left.and.bubble.right.fill"];
            cell.imageView.tintColor = [UIColor systemTealColor];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"安全體檢";
            cell.detailTextLabel.text = @"啟動項、注入插件、SSH 暴露面（只讀，不改系統）";
            cell.imageView.image = [UIImage systemImageNamed:@"shield.lefthalf.filled"];
            cell.imageView.tintColor = [UIColor systemRedColor];
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"系統狀態";
            cell.detailTextLabel.text = @"記憶體、磁碟、各程式占用（唯讀）";
            cell.imageView.image = [UIImage systemImageNamed:@"memorychip"];
            cell.imageView.tintColor = [UIColor systemIndigoColor];
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"使用說明";
            cell.imageView.image = [UIImage systemImageNamed:@"info.circle"];
            cell.imageView.tintColor = [UIColor secondaryLabelColor];
        } else {
            cell.textLabel.text = @"分享診斷報告";
            cell.detailTextLabel.text = @"裝了卻沒反應時，把報告貼給我看";
            cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
            cell.imageView.tintColor = [UIColor secondaryLabelColor];
        }
    }
    return cell;
}

- (UIImage *)iconForState:(DSHState)state {
    switch (state) {
        case DSHStateOK: return [UIImage systemImageNamed:@"checkmark.circle.fill"];
        case DSHStateWarn: return [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
        case DSHStateBad: return [UIImage systemImageNamed:@"xmark.circle.fill"];
        default: return [UIImage systemImageNamed:@"questionmark.circle"];
    }
}

- (UIColor *)colorForState:(DSHState)state {
    switch (state) {
        case DSHStateOK: return [UIColor systemGreenColor];
        case DSHStateWarn: return [UIColor systemOrangeColor];
        case DSHStateBad: return [UIColor systemRedColor];
        default: return [UIColor tertiaryLabelColor];
    }
}

#pragma mark - 交互

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;

    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self.navigationController pushViewController:[DSHChatViewController new] animated:YES];
        } else if (indexPath.row == 1) {
            [self.navigationController pushViewController:[DSHSecurityViewController new] animated:YES];
        } else if (indexPath.row == 2) {
            [self.navigationController pushViewController:[DSHSystemViewController new] animated:YES];
        } else if (indexPath.row == 3) {
            [self showAbout];
        } else {
            [self shareReport];
        }
        return;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == kDSHRowToggle) return; // 开关交给 UISwitch 自己处理
        if (indexPath.row == kDSHRowInstall) {
            [self installTapped];
        } else if (indexPath.row == kDSHRowRespring) {
            [self respringTapped];
        } else if (indexPath.row == kDSHRowPreview) {
            [self.navigationController pushViewController:[DSHPetPreviewViewController new] animated:YES];
        }
        return;
    }
}

#pragma mark - 桌宠开关

- (void)toggleChanged:(UISwitch *)sender {
    BOOL wanted = sender.on;
    BOOL now = [DSHPetDiagnostics setPetEnabled:wanted];
    if (now != wanted) {
        sender.on = now;
        [self alert:@"開關沒有生效"
            message:@"寫不進 /var/jb/Library/DSHPet/。通常是插件本體還沒安裝，"
                     "或 deb 的 postinst 沒跑過（目錄還是 root 權限）。"];
        return;
    }
    if (![DSHPetDiagnostics pluginInstalled]) {
        [self alert:@"還沒安裝桌寵本體"
            message:@"開關狀態已經記下來了，但 DSHPet.dylib 還沒進 SpringBoard，"
                     "所以畫面上不會有變化。請先點上面的「安裝 / 重裝桌寵」裝一次。"];
    }
}

- (void)installTapped {
    // 路线一：助手已装好（说明之前装过一次），直接用内置 payload 一键装，
    // 不经过 Sileo、不需要联网、也不需要用户再选一次 App。
    if ([DSHPetDiagnostics helperInstalled] && [DSHPetDiagnostics bundledPayloadURL]) {
        [self installInPlace];
        return;
    }
    // 路线二：第一次安装，助手还不存在，只能把 deb 交给 Sileo 装。
    NSURL *deb = [DSHPetDiagnostics bundledDebURL];
    if (!deb) {
        [self alert:@"找不到內建的 DSHPet.deb" message:@"這個 IPA 打包時沒有把 deb 一起放進來，請重新下載完整版。"];
        return;
    }
    [self prepareAndPresent:deb];
}

// 一键安装：屏幕上盖个遮罩，后台让 setuid 助手解 payload，完成后 SpringBoard 会自己重启。
- (void)installInPlace {
    [self showBusy:@"正在安裝桌寵…\n解壓縮 + 簽名，大約十幾秒，期間請不要離開。"];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL ok = [DSHPetDiagnostics installViaHelper:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            DSHPetMainViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf hideBusy];
            if (ok) {
                // 助手最后会 sbreload，这里只提示，不做别的
                [strongSelf alert:@"安裝完成"
                          message:@"桌寵已經寫進 SpringBoard，畫面馬上會閃一下重載。\n如果沒看到桌寵，回到桌面等一下，或下拉通知中心再收起來。"];
            } else {
                [strongSelf alert:@"安裝失敗"
                          message:@"助手沒能把 payload 解到 /var/jb。可能是越獄環境不是 rootless（沒有 /var/jb），"
                                   "或助手權限被改掉了。請點「分享診斷報告」把內容發給我。"];
            }
        });
    });
}

- (void)prepareAndPresent:(NSURL *)deb {
    [self showBusy:@"正在準備安裝檔…\n約 140 MB，第一次會慢一點"];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *ready = [DSHPetDiagnostics preparedDebURL] ?: deb;
        dispatch_async(dispatch_get_main_queue(), ^{
            DSHPetMainViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf hideBusy];
            [strongSelf presentDebMenu:ready];
        });
    });
}

- (void)presentDebMenu:(NSURL *)deb {
    self.docController = [UIDocumentInteractionController interactionControllerWithURL:deb];
    self.docController.delegate = self;
    self.docController.name = @"DSHPet";

    BOOL shown = [self.docController presentOpenInMenuFromRect:self.view.bounds
                                                        inView:self.view
                                                      animated:YES];
    if (!shown) {
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[deb]
                                                                              applicationActivities:nil];
        activity.popoverPresentationController.sourceView = self.view;
        activity.popoverPresentationController.sourceRect = self.view.bounds;
        [self presentViewController:activity animated:YES completion:nil];
    }
}

- (void)respringTapped {
    if ([DSHPetDiagnostics respring]) {
        // SpringBoard 会被杀掉，本 App 下次回到前台时会重新探测
        return;
    }
    [self alert:@"無法重啟 SpringBoard"
        message:@"重啟助手尚未安裝（它隨桌寵插件一起安裝）。請先點「安裝 / 重裝桌寵」，裝好之後就能一鍵重啟。"];
}

- (void)shareReport {
    NSString *text = [DSHPetDiagnostics reportText];

    // 不能用 UIActivityViewController：这台机器上 ShareSheet 会在它自己的
    // diffable data source 里越界崩溃（栈顶 -[__NSArrayM removeObjectsInRange:]），
    // 和我们要分享的内容无关。改成「复制到剪贴板 + 落地成文件」。
    [UIPasteboard generalPasteboard].string = text;

    NSString *path = [DSHPetDiagnostics writeReportFile:text prefix:@"DSHPet-diagnose"];
    NSString *msg = path
        ? [NSString stringWithFormat:@"已複製到剪貼簿，也存成檔案了：\n\n%@\n\n直接貼給我就行，或用 Filza 打開那個檔案。", path]
        : @"已複製到剪貼簿，直接貼給我就行。";
    [self alert:@"報告已準備好" message:msg];
}

- (void)showAbout {
    NSString *body =
    @"安裝步驟\n"
    @"1. 點「安裝 / 重裝桌寵」，在彈出的選單裡選 Sileo。\n"
    @"2. Sileo 裡確認安裝，deb 大約 140 MB，解包需要一點時間。\n"
    @"3. 裝完 postinst 會自動重啟 SpringBoard，桌寵直接出現在桌面。\n"
    @"4. 若沒自動重啟，回到本 App 點「重啟 SpringBoard」。\n"
    @"\n"
    @"操作方式\n"
    @"· 單擊：打個招呼\n"
    @"· 長按：打開選單（睡覺、隨機表演、回角落、大小、隱藏 10 分鐘）\n"
    @"· 拖著甩：會被扔出去\n"
    @"\n"
    @"常見問題\n"
    @"· 桌面看不到寵物：先確認上面「狀態」是不是全綠；不綠就照提示處理。\n"
    @"· 手機重啟後：需要重新跑一次 Dopamine 越獄，插件本身不用重裝。\n"
    @"· 想關掉日誌：預設是關的；要開就在 /var/jb/Library/DSHPet/debug 放個空檔案。\n"
    @"\n"
    @"本 App 只是安裝器 + 預覽，桌寵本體是注入 SpringBoard 的插件。";
    [self.navigationController pushViewController:[DSHTextViewController heading:@"使用說明" body:body] animated:YES];
}

- (void)showBusy:(NSString *)text {
    [self hideBusy];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:text
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    self.busyAlert = alert;
}

- (void)hideBusy {
    [self.busyAlert dismissViewControllerAnimated:NO completion:nil];
    self.busyAlert = nil;
}

- (void)alert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
