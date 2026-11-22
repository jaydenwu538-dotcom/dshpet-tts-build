//
//  DSHSecurityViewController.m
//

#import "DSHSecurityViewController.h"
#import "DSHSecurity.h"
#import "DSHPetDiagnostics.h"

#pragma mark - 单条详情

@interface DSHSecurityDetailViewController : UITableViewController
@property (nonatomic, strong) DSHFinding *finding;
@end

@implementation DSHSecurityDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.finding.category;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;   // 说明 / 证据 / 建议
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return self.finding.severityText;
        case 1: return self.finding.evidence.count > 0 ? @"證據" : nil;
        default: return self.finding.fixHint.length > 0 ? @"建議" : nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.finding.path.length > 0 ? 2 : 1;
    if (section == 1) return self.finding.evidence.count;
    return self.finding.fixHint.length > 0 ? 1 : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"detail";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.textLabel.textColor = [UIColor labelColor];
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = self.finding.detail;
        } else {
            cell.textLabel.text = self.finding.path;
            cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = self.finding.evidence[indexPath.row];
        cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.textLabel.text = self.finding.fixHint;
        cell.textLabel.textColor = [UIColor systemBlueColor];
    }
    return cell;
}

@end

#pragma mark - 体检主页面

@interface DSHSecurityViewController ()

@property (nonatomic, copy) NSArray<DSHFinding *> *findings;
@property (nonatomic, assign) BOOL scanning;
@property (nonatomic, assign) BOOL scanned;

@end

@implementation DSHSecurityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"安全體檢";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                      target:self
                                                      action:@selector(shareReport)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.scanned && !self.scanning) {
        [self runChecks];
    }
}

#pragma mark - 分区

- (NSArray<DSHFinding *> *)findingsWithSeverity:(DSHSeverity)sev {
    NSMutableArray<DSHFinding *> *out = [NSMutableArray array];
    for (DSHFinding *f in self.findings) {
        if (f.severity == sev) [out addObject:f];
    }
    return out;
}

- (NSInteger)countForSeverity:(DSHSeverity)sev {
    NSInteger n = 0;
    for (DSHFinding *f in self.findings) {
        if (f.severity == sev) n++;
    }
    return n;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return nil;
        case 1: return [self countForSeverity:DSHSeverityCritical] > 0 ? @"危險 —— 建議立刻處理" : nil;
        case 2: return [self countForSeverity:DSHSeverityWarn] > 0 ? @"注意 —— 值得確認" : nil;
        default: return [self countForSeverity:DSHSeverityInfo] > 0 ? @"訊息" : nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1;
        case 1: return [self countForSeverity:DSHSeverityCritical];
        case 2: return [self countForSeverity:DSHSeverityWarn];
        default: return [self countForSeverity:DSHSeverityInfo];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *reuse = @"summary";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
            cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            cell.detailTextLabel.numberOfLines = 0;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        if (self.scanning) {
            cell.textLabel.text = @"正在體檢…";
            cell.detailTextLabel.text = @"逐個解析 dylib 結構與啟動項，稍等幾秒。";
            UIActivityIndicatorView *spinner =
                [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            [spinner startAnimating];
            cell.accessoryView = spinner;
        } else if (!self.scanned) {
            cell.textLabel.text = @"開始體檢";
            cell.detailTextLabel.text = @"全部只讀，不會改動你的系統檔案。";
            cell.accessoryView = nil;
        } else {
            NSInteger c = [self countForSeverity:DSHSeverityCritical];
            NSInteger w = [self countForSeverity:DSHSeverityWarn];
            NSInteger i = [self countForSeverity:DSHSeverityInfo];
            cell.textLabel.text = c > 0 ? @"體檢完成，有需要處理的項目"
                                        : (w > 0 ? @"體檢完成，有幾項值得留意" : @"體檢完成，未發現明顯風險");
            cell.detailTextLabel.text = [NSString stringWithFormat:@"危險 %ld · 注意 %ld · 訊息 %ld　　點一下重新檢查",
                                         (long)c, (long)w, (long)i];
            cell.accessoryView = nil;
        }
        return cell;
    }

    static NSString *reuse = @"finding";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    DSHFinding *f = nil;
    if (indexPath.section == 1) f = [self findingsWithSeverity:DSHSeverityCritical][indexPath.row];
    else if (indexPath.section == 2) f = [self findingsWithSeverity:DSHSeverityWarn][indexPath.row];
    else f = [self findingsWithSeverity:DSHSeverityInfo][indexPath.row];

    cell.textLabel.text = f.title;
    cell.detailTextLabel.text = f.detail;

    NSString *symbol = @"info.circle";
    UIColor *color = [UIColor systemGrayColor];
    if (f.severity == DSHSeverityCritical) { symbol = @"exclamationmark.octagon.fill"; color = [UIColor systemRedColor]; }
    else if (f.severity == DSHSeverityWarn) { symbol = @"exclamationmark.triangle.fill"; color = [UIColor systemOrangeColor]; }
    cell.imageView.image = [[UIImage systemImageNamed:symbol]
                            imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        [self runChecks];
        return;
    }

    DSHFinding *f = nil;
    if (indexPath.section == 1) f = [self findingsWithSeverity:DSHSeverityCritical][indexPath.row];
    else if (indexPath.section == 2) f = [self findingsWithSeverity:DSHSeverityWarn][indexPath.row];
    else f = [self findingsWithSeverity:DSHSeverityInfo][indexPath.row];

    DSHSecurityDetailViewController *vc = [DSHSecurityDetailViewController new];
    vc.finding = f;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - 执行

- (void)runChecks {
    if (self.scanning) return;
    self.scanning = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.tableView reloadData];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<DSHFinding *> *result = [DSHSecurity runAllChecks];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.findings = result;
            self.scanning = NO;
            self.scanned = YES;
            self.navigationItem.rightBarButtonItem.enabled = YES;
            [self.tableView reloadData];
        });
    });
}

- (void)shareReport {
    if (self.findings.count == 0) return;
    NSString *text = [DSHSecurity reportTextForFindings:self.findings];

    // 同样的理由：UIActivityViewController 在这台越狱机上会崩在 ShareSheet 内部，
    // 所以只复制 + 落文件，不调系统分享面板。
    [UIPasteboard generalPasteboard].string = text;

    NSString *path = [DSHPetDiagnostics writeReportFile:text prefix:@"DSHPet-security"];
    NSString *msg = path
        ? [NSString stringWithFormat:@"已複製到剪貼簿，也存成檔案了：\n\n%@\n\n直接貼給我就行，或用 Filza 打開那個檔案。", path]
        : @"已複製到剪貼簿，直接貼給我就行。";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"報告已準備好"
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
