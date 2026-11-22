//
//  DSHSecurity.m
//  安全体检的实现。全部只读。
//

#import "DSHSecurity.h"
#import "DSHMachO.h"

#include <unistd.h>
#include <sys/stat.h>

#pragma mark - 路径

static NSString *const kJB = @"/var/jb";
static NSString *const kDylibDir = @"/var/jb/Library/MobileSubstrate/DynamicLibraries";
static NSString *const kJBLaunchDaemons = @"/var/jb/Library/LaunchDaemons";
static NSString *const kRootLaunchDaemons = @"/Library/LaunchDaemons";
static NSString *const kJBLaunchAgents = @"/var/jb/Library/LaunchAgents";
static NSString *const kRootLaunchAgents = @"/Library/LaunchAgents";
static NSString *const kSSHDConfig = @"/var/jb/etc/ssh/sshd_config";

#pragma mark - 小工具

static BOOL DSHPathIsDir(NSString *path) {
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir;
}

static BOOL DSHPathIsFile(NSString *path) {
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && !isDir;
}

static NSDictionary *DSHReadPlist(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) return nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:NULL
                                                           error:NULL];
    if ([plist isKindOfClass:[NSDictionary class]]) return plist;
    return nil;
}

// 启动项里出现这些前缀，视为「系统或已知工具」，不再啰嗦
static BOOL DSHLabelIsKnown(NSString *label) {
    if (label.length == 0) return NO;
    static NSArray<NSString *> *known = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        known = @[ @"com.apple.", @"com.opa334.", @"com.tigisoftware.filza",
                   @"com.zjx.zxtouch", @"com.openssh.sshd", @"us.diatr.shshd",
                   @"org.coolstar.", @"com.ichitaso.", @"com.ex.substitute",
                   @"xyz.willy.zebra", @"org.coolstar.sileo" ];
    });
    for (NSString *prefix in known) {
        if ([label hasPrefix:prefix]) return YES;
    }
    return NO;
}

@implementation DSHFinding

+ (instancetype)findingWithSeverity:(DSHSeverity)sev
                           category:(NSString *)category
                              title:(NSString *)title
                             detail:(NSString *)detail {
    DSHFinding *f = [DSHFinding new];
    f.severity = sev;
    f.category = category;
    f.title = title;
    f.detail = detail;
    f.evidence = @[];
    return f;
}

- (NSString *)severityText {
    switch (self.severity) {
        case DSHSeverityCritical: return @"危險";
        case DSHSeverityWarn: return @"注意";
        default: return @"訊息";
    }
}

@end

#pragma mark - 体检

@implementation DSHSecurity

+ (NSArray<DSHFinding *> *)runAllChecks {
    NSMutableArray<DSHFinding *> *all = [NSMutableArray array];
    [all addObjectsFromArray:[self checkExposure]];
    [all addObjectsFromArray:[self checkStartupItems]];
    [all addObjectsFromArray:[self checkTweaks]];
    [all addObjectsFromArray:[self checkInstallers]];

    // 危险的排前面
    [all sortUsingComparator:^NSComparisonResult(DSHFinding *a, DSHFinding *b) {
        if (a.severity != b.severity) return a.severity > b.severity ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    return all;
}

#pragma mark 1. 越狱暴露面

+ (NSArray<DSHFinding *> *)checkExposure {
    NSMutableArray<DSHFinding *> *out = [NSMutableArray array];

    if (!DSHPathIsDir(kJB)) {
        [out addObject:[DSHFinding findingWithSeverity:DSHSeverityWarn
                                             category:@"越狱环境"
                                                title:@"找不到 /var/jb"
                                               detail:@"这台设备看起来没有 rootless 越狱环境，后面的检查会大量跳过。"]];
        return out;
    }

    // --- SSH ---
    BOOL hasOpenSSH = DSHPathIsFile([kJBLaunchDaemons stringByAppendingPathComponent:@"com.openssh.sshd.plist"]);
    BOOL hasDropbear = DSHPathIsFile([kJBLaunchDaemons stringByAppendingPathComponent:@"com.jerrydoe.dropbear.plist"]) ||
                       DSHPathIsFile([kJBLaunchDaemons stringByAppendingPathComponent:@"com.dropbear.plist"]);

    if (hasOpenSSH || hasDropbear) {
        NSString *cfg = [NSString stringWithContentsOfFile:kSSHDConfig
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
        BOOL permitRoot = NO;
        BOOL passwordAuth = NO;
        NSMutableArray<NSString *> *ev = [NSMutableArray array];

        if (cfg) {
            for (NSString *line in [cfg componentsSeparatedByString:@"\n"]) {
                NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (t.length == 0 || [t hasPrefix:@"#"]) continue;
                NSString *lower = t.lowercaseString;
                if ([lower hasPrefix:@"permitrootlogin yes"]) { permitRoot = YES; [ev addObject:t]; }
                if ([lower hasPrefix:@"passwordauthentication yes"]) { passwordAuth = YES; [ev addObject:t]; }
            }
        }

        DSHSeverity sev = (permitRoot && passwordAuth) ? DSHSeverityCritical : DSHSeverityWarn;
        NSString *detail;
        if (permitRoot && passwordAuth) {
            detail = @"SSH 常驻并且在用「root + 密码」登录。越狱机上这是最危险的一种组合：任何能连到这个端口的人，只要知道密码就拿到完整 root 权限。";
        } else if (passwordAuth) {
            detail = @"SSH 常驻并允许密码登录。如果密码是弱口令，局域网内的人可以直接进到系统里。";
        } else {
            detail = @"SSH 服务常驻。如果你平时不用，建议关掉；用的时候再开，暴露面会小很多。";
        }

        DSHFinding *f = [DSHFinding findingWithSeverity:sev
                                                category:@"越狱暴露面"
                                                   title:@"SSH 服务正在常驻"
                                                  detail:detail];
        f.path = hasOpenSSH ? [kJBLaunchDaemons stringByAppendingPathComponent:@"com.openssh.sshd.plist"]
                            : [kJBLaunchDaemons stringByAppendingPathComponent:@"com.jerrydoe.dropbear.plist"];
        f.evidence = [ev copy];
        f.fixHint = @"确认密码不是 alpine；或在 Sileo 里装个 SSH 开关工具，平时关掉，需要时再开。";
        [out addObject:f];
    }

    // --- 登录密码文件是否可读（可读才有意义去判断） ---
    NSString *masterPasswd = [kJB stringByAppendingPathComponent:@"etc/master.passwd"];
    if (DSHPathIsFile(masterPasswd)) {
        NSString *content = [NSString stringWithContentsOfFile:masterPasswd
                                                      encoding:NSUTF8StringEncoding
                                                         error:NULL];
        if (content.length > 0) {
            NSMutableArray<NSString *> *ev = [NSMutableArray array];
            for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
                if ([line hasPrefix:@"root:"] || [line hasPrefix:@"mobile:"]) {
                    [ev addObject:line];
                }
            }
            if (ev.count > 0) {
                [out addObject:({
                    DSHFinding *f = [DSHFinding findingWithSeverity:DSHSeverityInfo
                                                           category:@"越狱暴露面"
                                                              title:@"当前 App 能直接读取账号密码文件"
                                                             detail:@"说明这个 App 拿到的权限比普通 App 高。这依赖 TrollStore 的 platform-application 授权，属预期行为，但也意味着「谁能装进这个 App 谁就能读到同样的东西」。"];
                    f.path = masterPasswd;
                    f.evidence = [ev copy];
                    f;
                })];
            }
        } else {
            [out addObject:({
                DSHFinding *f = [DSHFinding findingWithSeverity:DSHSeverityInfo
                                                       category:@"越狱暴露面"
                                                          title:@"无法读取账号密码文件"
                                                         detail:@"这反而是正常状态。请自己确认 root 和 mobile 的密码不是默认的 alpine。"];
                f.path = masterPasswd;
                f.fixHint = @"用 SSH 登进去执行 passwd 改一下密码，改完这条风险就没了。";
                f;
            })];
        }
    }

    // --- apt 软件源 ---
    NSMutableArray<NSString *> *sources = [NSMutableArray array];
    NSString *mainList = [kJB stringByAppendingPathComponent:@"etc/apt/sources.list"];
    if (DSHPathIsFile(mainList)) {
        NSString *c = [NSString stringWithContentsOfFile:mainList encoding:NSUTF8StringEncoding error:NULL];
        if (c.length > 0) {
            for (NSString *line in [c componentsSeparatedByString:@"\n"]) {
                NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([t hasPrefix:@"deb "]) [sources addObject:t];
            }
        }
    }
    NSString *sourcesDir = [kJB stringByAppendingPathComponent:@"etc/apt/sources.list.d"];
    if (DSHPathIsDir(sourcesDir)) {
        NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:sourcesDir error:NULL];
        for (NSString *name in files) {
            if (![name hasSuffix:@".list"] && ![name hasSuffix:@".sources"]) continue;
            NSString *c = [NSString stringWithContentsOfFile:[sourcesDir stringByAppendingPathComponent:name]
                                                    encoding:NSUTF8StringEncoding
                                                       error:NULL];
            if (c.length == 0) continue;
            for (NSString *line in [c componentsSeparatedByString:@"\n"]) {
                NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([t hasPrefix:@"deb "] || [t hasPrefix:@"URIs:"]) [sources addObject:t];
            }
        }
    }

    if (sources.count > 0) {
        NSMutableArray<NSString *> *plain = [NSMutableArray array];
        for (NSString *line in sources) {
            if ([line containsString:@"http://"]) [plain addObject:line];
        }
        DSHSeverity sev = plain.count > 0 ? DSHSeverityWarn : DSHSeverityInfo;
        DSHFinding *f = [DSHFinding findingWithSeverity:sev
                                                category:@"越狱暴露面"
                                                   title:[NSString stringWithFormat:@"共有 %lu 个软件源", (unsigned long)sources.count]
                                                  detail:plain.count > 0
                          ? @"其中有源走的是 http 明文。包内容和校验信息在传输途中都可能被替换，等于把「装什么」的决定权交给了网络链路上的任何人。"
                          : @"软件源都走 https，传输层没问题。真正要留意的是源本身是否可信 —— 你从这个源装进来的每个 deb 都会以 root 身份落到 /var/jb。"];
        f.evidence = [sources copy];
        f.fixHint = @"删掉不认识的源，尤其是 http 明文的。";
        [out addObject:f];
    }

    return out;
}

#pragma mark 2. 启动项

+ (NSArray<DSHFinding *> *)checkStartupItems {
    NSMutableArray<DSHFinding *> *out = [NSMutableArray array];
    NSArray<NSString *> *dirs = @[ kJBLaunchDaemons, kRootLaunchDaemons, kJBLaunchAgents, kRootLaunchAgents ];

    NSInteger scanned = 0;
    NSMutableArray<DSHFinding *> *suspicious = [NSMutableArray array];

    for (NSString *dir in dirs) {
        if (!DSHPathIsDir(dir)) continue;
        NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL];
        for (NSString *name in files) {
            if (![name hasSuffix:@".plist"]) continue;
            NSString *full = [dir stringByAppendingPathComponent:name];
            NSDictionary *plist = DSHReadPlist(full);
            if (!plist) continue;
            scanned++;

            NSString *label = plist[@"Label"];
            if (![label isKindOfClass:[NSString class]]) label = name.stringByDeletingPathExtension;

            NSString *program = plist[@"Program"];
            if (![program isKindOfClass:[NSString class]]) program = nil;

            NSArray *args = plist[@"ProgramArguments"];
            if (![args isKindOfClass:[NSArray class]]) args = nil;

            BOOL runAtLoad = [plist[@"RunAtLoad"] boolValue];
            BOOL disabled = [plist[@"Disabled"] boolValue];
            BOOL keepAlive = plist[@"KeepAlive"] != nil;

            if (args.count > 0 && !program) {
                id first = args.firstObject;
                if ([first isKindOfClass:[NSString class]]) program = first;
            }

            NSMutableArray<NSString *> *ev = [NSMutableArray array];
            if (program) [ev addObject:[NSString stringWithFormat:@"Program: %@", program]];
            if (args.count > 0) [ev addObject:[NSString stringWithFormat:@"Arguments: %@", [args componentsJoinedByString:@" "]]];
            [ev addObject:[NSString stringWithFormat:@"RunAtLoad: %@  KeepAlive: %@  Disabled: %@",
                           runAtLoad ? @"true" : @"false",
                           keepAlive ? @"true" : @"false",
                           disabled ? @"true" : @"false"]];

            DSHSeverity sev = DSHSeverityInfo;
            NSString *why = nil;

            // OpenSSH 自己的 plist 就是用 `sh sshd-keygen-wrapper` 起来的：wrapper 负责
            // 检查/生成 host key 后再 exec sshd。ZYTouch 的 shshd 同理（shshd-wrapper）。
            // 这两个是已知的可信写法，别按「shell 启动 = 后门」判死。
            BOOL knownWrapper = [label isEqualToString:@"com.openssh.sshd"] ||
                                [label isEqualToString:@"us.diatr.shshd"];
            BOOL wrapperStyle = args.count >= 2 &&
                [[args[0] description] hasSuffix:@"sh"] &&
                [[args[1] description] hasSuffix:@"-wrapper"];

            // 从用户可写目录启动 = 极危险（谁写进去谁就能以 root 跑）
            BOOL fromWritable = (program != nil) &&
                ([program hasPrefix:@"/var/mobile"] || [program hasPrefix:@"/private/var/mobile"] ||
                 [program hasPrefix:@"/var/tmp"] || [program hasPrefix:@"/tmp"]);
            if (fromWritable) {
                sev = DSHSeverityCritical;
                why = @"这个守护进程的可执行文件放在用户可写目录里。任何 App 都能改写那个文件，重启后就以 root 身份执行 —— 这是经典的后门布置方式。";
            } else if (args.count >= 2 &&
                       ([[args[0] description] hasSuffix:@"sh"] || [[args[0] description] hasSuffix:@"bash"])) {
                if (knownWrapper || wrapperStyle) {
                    continue;   // OpenSSH / ZYTouch 的 wrapper 模式，正常
                }
                sev = DSHSeverityCritical;
                why = @"用 shell 直接执行命令串启动，而不是跑一个正经程序。这种写法本身不是罪证，但后门和挖矿脚本几乎都长这样。";
            } else if (runAtLoad && !disabled && !DSHLabelIsKnown(label)) {
                sev = DSHSeverityWarn;
                why = @"开机就会启动，而且不属于系统或常见工具。值得确认一下它是什么。";
            }

            if (why == nil) continue;   // 正常项不打扰

            DSHFinding *f = [DSHFinding findingWithSeverity:sev
                                                    category:@"启动项"
                                                       title:label
                                                      detail:why];
            f.path = full;
            f.evidence = [ev copy];
            f.fixHint = sev == DSHSeverityCritical
                ? @"确认不是你自己装的工具后，到 Filza 里把这个 plist 删掉，然后重启。"
                : @"如果不认识它，先在 Sileo 里查这个包名再决定留不留。";
            [suspicious addObject:f];
        }
    }

    [out addObjectsFromArray:suspicious];
    if (suspicious.count == 0) {
        [out addObject:[DSHFinding findingWithSeverity:DSHSeverityInfo
                                             category:@"启动项"
                                                title:[NSString stringWithFormat:@"%ld 个开机自启项，没有异常", (long)scanned]
                                               detail:@"逐个解析了 LaunchDaemons / LaunchAgents 里的 plist，没有发现从可写目录启动、或用 shell 直接执行命令的项。"]];
    } else {
        [out addObject:[DSHFinding findingWithSeverity:DSHSeverityInfo
                                             category:@"启动项"
                                                title:[NSString stringWithFormat:@"共扫描 %ld 个开机自启项", (long)scanned]
                                               detail:@"其余项未发现可疑特征。"]];
    }

    return out;
}

#pragma mark 3. 插件审计

+ (NSArray<DSHFinding *> *)checkTweaks {
    NSMutableArray<DSHFinding *> *out = [NSMutableArray array];

    if (!DSHPathIsDir(kDylibDir)) {
        [out addObject:[DSHFinding findingWithSeverity:DSHSeverityInfo
                                             category:@"插件审计"
                                                title:@"没有找到 tweak 目录"
                                               detail:@"说明这台机器上还没有注入式插件，或注入器用了别的路径。"]];
        return out;
    }

    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kDylibDir error:NULL];
    NSMutableArray<NSString *> *dylibs = [NSMutableArray array];
    for (NSString *name in files) {
        if ([name hasSuffix:@".dylib"]) [dylibs addObject:name];
    }
    [dylibs sortUsingSelector:@selector(compare:)];

    NSInteger risky = 0;
    for (NSString *name in dylibs) {
        NSString *full = [kDylibDir stringByAppendingPathComponent:name];
        DSHMachOReport *rep = [DSHMachO analyzeFile:full maxBytes:4 * 1024 * 1024];
        if (!rep || !rep.isMachO) continue;

        // 自己写的插件不吓唬用户，但仍如实列出能力
        BOOL isSelf = [name isEqualToString:@"DSHPet.dylib"];
        // 中控 / ZYTouch（com.zjx.ioscontrol）本来就是「让电脑远程敲命令」的工具，
        // 它导入 execve/posix_spawn、内嵌 /bin/sh 是本职功能，不是可疑特征。
        // 仍降为「訊息」并说明，但不占用「需要留意」的计数。
        BOOL isRemoteControl = [name isEqualToString:@"pccontrol.dylib"];

        if (rep.riskLevel >= 1 || isSelf || isRemoteControl) {
            DSHSeverity sev = rep.riskLevel == 2 ? DSHSeverityCritical
                            : (rep.riskLevel == 1 ? DSHSeverityWarn : DSHSeverityInfo);
            if (isSelf || isRemoteControl) {
                sev = DSHSeverityInfo;
            } else if (sev >= DSHSeverityWarn) {
                risky++;
            }

            NSString *title = name;
            NSString *detail = nil;
            if (isSelf) {
                title = [NSString stringWithFormat:@"%@（本插件）", name];
                detail = @"这是桌宠自己。它会调用 posix_spawn 来重启 SpringBoard，所以命中了进程执行规则 —— 属预期。";
            } else if (isRemoteControl) {
                title = [NSString stringWithFormat:@"%@（中控 / ZYTouch）", name];
                detail = [NSString stringWithFormat:@"这是你自己装的远程控制组件（com.zjx.ioscontrol），"
                          @"它的本职工作就是执行 shell 命令，所以风险分高（%ld）是必然的，不代表中毒。"
                          @"真正要留意的是：谁能连上它。用完把 6000 端口的服务停掉更稳。",
                          (long)rep.riskScore];
            } else {
                detail = [NSString stringWithFormat:@"%@，风险分 %ld。%@",
                          rep.riskText, (long)rep.riskScore,
                          rep.reasons.count > 0 ? [rep.reasons componentsJoinedByString:@"；"] : @""];
            }

            DSHFinding *f = [DSHFinding findingWithSeverity:sev
                                                    category:@"插件审计"
                                                       title:title
                                                      detail:detail];
            f.path = full;
            NSMutableArray<NSString *> *ev = [NSMutableArray array];
            if (rep.arch.length > 0) [ev addObject:[NSString stringWithFormat:@"架构：%@", rep.arch]];
            if (rep.linkedLibraries.count > 0) [ev addObject:[NSString stringWithFormat:@"链接：%@", [rep.linkedLibraries componentsJoinedByString:@", "]]];
            if (rep.suspiciousSymbols.count > 0) [ev addObject:[NSString stringWithFormat:@"危险符号：%@", [rep.suspiciousSymbols componentsJoinedByString:@", "]]];
            if (rep.suspiciousStrings.count > 0) [ev addObject:[NSString stringWithFormat:@"可疑字符串（最多 6 条）：%@", [[rep.suspiciousStrings subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)6, rep.suspiciousStrings.count))] componentsJoinedByString:@" | "]]];
            f.evidence = [ev copy];
            if (sev >= DSHSeverityWarn) {
                f.fixHint = @"确认不了来源就直接在 Filza 里删掉这个 dylib，然后 respring；对应的 .plist 一并删。";
            }
            [out addObject:f];
        }
    }

    NSString *summary = [NSString stringWithFormat:@"共 %lu 个注入式插件，%ld 个需要留意",
                         (unsigned long)dylibs.count, (long)risky];
    [out addObject:[DSHFinding findingWithSeverity:(risky > 0 ? DSHSeverityInfo : DSHSeverityInfo)
                                         category:@"插件审计"
                                            title:summary
                                           detail:@"判定依据是静态分析：链接了哪些框架、导入了哪些危险符号、内嵌了哪些命令与网络地址。没有实际运行它们。"]];
    return out;
}

#pragma mark 4. 安装包

+ (NSArray<DSHFinding *> *)checkInstallers {
    NSMutableArray<DSHFinding *> *out = [NSMutableArray array];
    NSArray<NSString *> *dirs = @[ @"/var/mobile/Media/Downloads", @"/var/mobile/Media/dsh", @"/var/mobile/Documents" ];

    NSMutableArray<NSString *> *packages = [NSMutableArray array];
    NSInteger dylibCount = 0;

    for (NSString *dir in dirs) {
        if (!DSHPathIsDir(dir)) continue;
        NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL];
        if (files.count > 300) files = [files subarrayWithRange:NSMakeRange(0, 300)];
        for (NSString *name in files) {
            NSString *lower = name.lowercaseString;
            NSString *full = [dir stringByAppendingPathComponent:name];
            if ([lower hasSuffix:@".deb"] || [lower hasSuffix:@".ipa"]) {
                unsigned long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:full error:NULL] fileSize];
                [packages addObject:[NSString stringWithFormat:@"%@  (%.1f MB)", full, size / 1024.0 / 1024.0]];
            } else if ([lower hasSuffix:@".dylib"]) {
                dylibCount++;
                DSHMachOReport *rep = [DSHMachO analyzeFile:full maxBytes:4 * 1024 * 1024];
                if (rep.isMachO && rep.riskLevel >= 1) {
                    DSHFinding *f = [DSHFinding findingWithSeverity:(rep.riskLevel == 2 ? DSHSeverityCritical : DSHSeverityWarn)
                                                            category:@"安装包"
                                                               title:name
                                                              detail:[NSString stringWithFormat:@"躺在下载目录里的 dylib，%@：%@",
                                                                      rep.riskText,
                                                                      rep.reasons.count > 0 ? [rep.reasons componentsJoinedByString:@"；"] : @"命中可疑规则"]];
                    f.path = full;
                    f.fixHint = @"不记得是谁给的，就直接删掉。";
                    [out addObject:f];
                }
            }
        }
    }

    if (packages.count > 0) {
        DSHFinding *f = [DSHFinding findingWithSeverity:DSHSeverityInfo
                                                category:@"安装包"
                                                   title:[NSString stringWithFormat:@"下载目录里有 %lu 个安装包", (unsigned long)packages.count]
                                                  detail:@"装着它们的人随时能用 Sileo / TrollStore 装上。装完记得清掉，别让旧包长期躺在那里。"];
        f.evidence = [packages copy];
        [out addObject:f];
    }

    if (dylibCount > 0) {
        [out addObject:[DSHFinding findingWithSeverity:DSHSeverityInfo
                                             category:@"安装包"
                                                title:[NSString stringWithFormat:@"另有 %ld 个散落的 dylib", (long)dylibCount]
                                               detail:@"这些文件没在注入目录里，暂时不会被加载；但谁把它们拷进 DynamicLibraries 就会生效。"]];
    }

    if (packages.count == 0 && dylibCount == 0) {
        [out addObject:[DSHFinding findingWithSeverity:DSHSeverityInfo
                                             category:@"安装包"
                                                title:@"下载目录很干净"
                                               detail:@"没有滞留的 deb / ipa / dylib。"]];
    }

    return out;
}

#pragma mark - 文本报告

+ (NSString *)reportTextForFindings:(NSArray<DSHFinding *> *)findings {
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"DSH 安全體檢報告\n%@\n", [fmt stringFromDate:[NSDate date]]];

    NSInteger critical = 0, warn = 0, info = 0;
    for (DSHFinding *f in findings) {
        if (f.severity == DSHSeverityCritical) critical++;
        else if (f.severity == DSHSeverityWarn) warn++;
        else info++;
    }
    [s appendFormat:@"危險 %ld · 注意 %ld · 訊息 %ld\n", (long)critical, (long)warn, (long)info];
    [s appendString:@"\n"];

    for (NSInteger level = DSHSeverityCritical; level >= DSHSeverityInfo; level--) {
        BOOL headerDone = NO;
        for (DSHFinding *f in findings) {
            if ((NSInteger)f.severity != level) continue;
            if (!headerDone) {
                NSString *name = level == DSHSeverityCritical ? @"【危險】" : (level == DSHSeverityWarn ? @"【注意】" : @"【訊息】");
                [s appendFormat:@"%@\n", name];
                headerDone = YES;
            }
            [s appendFormat:@"· %@  —— %@\n", f.title, f.detail];
            if (f.path.length > 0) [s appendFormat:@"  路徑：%@\n", f.path];
            for (NSString *line in f.evidence) {
                [s appendFormat:@"    %@\n", line];
            }
            if (f.fixHint.length > 0) [s appendFormat:@"  建議：%@\n", f.fixHint];
            [s appendString:@"\n"];
        }
    }
    return s;
}

@end
