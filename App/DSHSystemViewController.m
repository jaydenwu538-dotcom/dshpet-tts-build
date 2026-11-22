//
//  DSHSystemViewController.m
//

#import "DSHSystemViewController.h"
#import "DSHSystemInfo.h"

typedef NS_ENUM(NSInteger, DSHSystemSection) {
    DSHSystemSectionMemory = 0,
    DSHSystemSectionMemoryDetail,
    DSHSystemSectionDisk,
    DSHSystemSectionDevice,
    DSHSystemSectionProcesses,
    DSHSystemSectionCount
};

@interface DSHSystemViewController ()

@property (nonatomic, strong) NSArray<DSHProcessInfo *> *processes;
@property (nonatomic) unsigned long long totalMem;
@property (nonatomic) unsigned long long usedMem;
@property (nonatomic) unsigned long long freeMem;
@property (nonatomic) unsigned long long reclaimableMem;
@property (nonatomic) NSInteger pressure;
@property (nonatomic) unsigned long long diskTotal;
@property (nonatomic) unsigned long long diskFree;
@property (nonatomic) BOOL loading;

@end

@implementation DSHSystemViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"系統狀態";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48.0;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                      target:self
                                                      action:@selector(refreshTapped)];

    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(refreshTapped) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = rc;

    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

#pragma mark - 取資料

- (void)refreshTapped {
    [self reload];
    [self.refreshControl endRefreshing];
}

- (void)reload {
    self.totalMem       = [DSHSystemInfo totalMemory];
    self.usedMem        = [DSHSystemInfo usedMemory];
    self.freeMem        = [DSHSystemInfo freeMemory];
    self.reclaimableMem = [DSHSystemInfo reclaimableMemory];
    self.pressure       = [DSHSystemInfo memoryPressure];
    self.diskTotal      = [DSHSystemInfo diskTotal];
    self.diskFree       = [DSHSystemInfo diskFree];
    self.processes      = [DSHSystemInfo topProcesses:40];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return DSHSystemSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((DSHSystemSection)section) {
        case DSHSystemSectionMemory:       return 1;
        case DSHSystemSectionMemoryDetail: return 4;
        case DSHSystemSectionDisk:         return 1;
        case DSHSystemSectionDevice:       return 3;
        case DSHSystemSectionProcesses:    return (NSInteger)self.processes.count + 1;
        default:                           return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((DSHSystemSection)section) {
        case DSHSystemSectionMemory:       return @"記憶體";
        case DSHSystemSectionDisk:         return @"磁碟";
        case DSHSystemSectionDevice:       return @"裝置";
        case DSHSystemSectionProcesses:    return [NSString stringWithFormat:@"處理程序（前 %lu 個，按記憶體排序）",
                                                   (unsigned long)MIN(self.processes.count, (NSUInteger)40)];
        default:                           return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ((DSHSystemSection)section == DSHSystemSectionProcesses) {
        return @"iOS 沒有全域處理程序樹的概念。別的 App 的常駐記憶體要靠 proc_pidinfo 讀，"
               @"沒有相應權限時會顯示「不可讀」——這是系統限制，不是這裡出錯。";
    }
    if ((DSHSystemSection)section == DSHSystemSectionMemoryDetail) {
        return @"「可回收」是 inactive + purgeable，系統吃緊時會自動收走，不算真正洩漏。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSHSystemSection section = (DSHSystemSection)indexPath.section;

    if (section == DSHSystemSectionMemory || section == DSHSystemSectionDisk) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bar"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                          reuseIdentifier:@"bar"];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

        if (section == DSHSystemSectionMemory) {
            unsigned long long total = self.totalMem;
            double ratio = total > 0 ? (double)self.usedMem / (double)total : 0.0;
            cell.textLabel.text = [NSString stringWithFormat:@"%@ / %@（%.0f%%）",
                                   [DSHSystemInfo formatBytes:self.usedMem],
                                   [DSHSystemInfo formatBytes:total],
                                   ratio * 100.0];

            NSString *hint = @"";
            if (self.pressure >= 0) {
                hint = self.pressure >= 80 ? @"壓力偏高，系統隨時可能殺背景程式"
                     : (self.pressure >= 50 ? @"壓力中等" : @"壓力正常");
                hint = [NSString stringWithFormat:@"記憶體壓力 %ld%%　%@", (long)self.pressure, hint];
            } else {
                hint = @"取不到記憶體壓力";
            }
            cell.detailTextLabel.text = hint;
            [self attachProgressToCell:cell ratio:ratio];
        } else {
            unsigned long long total = self.diskTotal;
            unsigned long long used = total > self.diskFree ? total - self.diskFree : 0;
            double ratio = total > 0 ? (double)used / (double)total : 0.0;
            cell.textLabel.text = [NSString stringWithFormat:@"已用 %@，剩 %@ / %@（%.0f%%）",
                                   [DSHSystemInfo formatBytes:used],
                                   [DSHSystemInfo formatBytes:self.diskFree],
                                   [DSHSystemInfo formatBytes:total],
                                   ratio * 100.0];
            cell.detailTextLabel.text = @"整個 / 分區";
            [self attachProgressToCell:cell ratio:ratio];
        }
        return cell;
    }

    if (section == DSHSystemSectionMemoryDetail) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"kv"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:@"kv"];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = UIColor.labelColor;

        NSArray<NSArray *> *rows = @[
            @[@"已使用",  [DSHSystemInfo formatBytes:self.usedMem]],
            @[@"空閒",    [DSHSystemInfo formatBytes:self.freeMem]],
            @[@"可回收",  [DSHSystemInfo formatBytes:self.reclaimableMem]],
            @[@"總容量",  [DSHSystemInfo formatBytes:self.totalMem]]
        ];
        NSArray *row = rows[(NSUInteger)indexPath.row];
        cell.textLabel.text = row[0];
        cell.detailTextLabel.text = row[1];
        return cell;
    }

    if (section == DSHSystemSectionDevice) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"kv"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:@"kv"];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        NSArray<NSArray *> *rows = @[
            @[@"機型", [DSHSystemInfo machineName] ?: @"未知"],
            @[@"處理器", [NSString stringWithFormat:@"%ld 核", (long)[DSHSystemInfo cpuCount]]],
            @[@"系統", [DSHSystemInfo systemVersion]]
        ];
        NSArray *row = rows[(NSUInteger)indexPath.row];
        cell.textLabel.text = row[0];
        cell.detailTextLabel.text = row[1];
        return cell;
    }

    // 處理程序
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"proc"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:@"proc"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.row == 0) {
        cell.textLabel.text = @"本 App";
        cell.textLabel.textColor = UIColor.systemTealColor;
        cell.detailTextLabel.text = [DSHSystemInfo formatBytes:self.usedMem];
        cell.detailTextLabel.textColor = UIColor.systemTealColor;
        return cell;
    }

    NSUInteger idx = (NSUInteger)indexPath.row - 1;
    if (idx >= self.processes.count) {
        cell.textLabel.text = @"";
        cell.detailTextLabel.text = @"";
        return cell;
    }

    DSHProcessInfo *p = self.processes[idx];
    cell.textLabel.text = p.name;
    cell.textLabel.textColor = UIColor.labelColor;
    if (p.readable) {
        cell.detailTextLabel.text = [DSHSystemInfo formatBytes:p.residentBytes];
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    } else {
        cell.detailTextLabel.text = @"不可讀";
        cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
    }
    return cell;
}

#pragma mark - 進度條

- (void)attachProgressToCell:(UITableViewCell *)cell ratio:(double)ratio {
    static const NSInteger kTag = 8801;

    UIProgressView *bar = (UIProgressView *)[cell.contentView viewWithTag:kTag];
    if (!bar) {
        bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        bar.tag = kTag;
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:bar];
        [NSLayoutConstraint activateConstraints:@[
            [bar.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [bar.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [bar.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10.0]
        ]];
    }

    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;
    bar.progress = (float)ratio;

    if (ratio >= 0.9) {
        bar.progressTintColor = UIColor.systemRedColor;
    } else if (ratio >= 0.75) {
        bar.progressTintColor = UIColor.systemOrangeColor;
    } else {
        bar.progressTintColor = UIColor.systemGreenColor;
    }
}

@end
