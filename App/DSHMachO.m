//
//  DSHMachO.m
//  只读的 Mach-O 体检。不做动态执行，纯静态判定。
//

#import "DSHMachO.h"

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#pragma mark - 常量（手写，不依赖 SDK 的 mach-o 头）

#define DSH_MH_MAGIC      0xfeedfaceu
#define DSH_MH_MAGIC_64   0xfeedfacfu
#define DSH_FAT_MAGIC     0xcafebabeu

#define DSH_LC_SEGMENT_64   0x19u
#define DSH_LC_LOAD_DYLIB   0x0cu

typedef struct {
    uint32_t magic;
    uint32_t nfat_arch;
} dsh_fat_header;

typedef struct {
    uint32_t cputype;
    uint32_t cpusubtype;
    uint32_t offset;
    uint32_t size;
    uint32_t align;
} dsh_fat_arch;

typedef struct {
    uint32_t magic;
    uint32_t cputype;
    uint32_t cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
    uint32_t reserved;
} dsh_mach_header_64;

typedef struct {
    uint32_t cmd;
    uint32_t cmdsize;
    char segname[16];
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    int32_t maxprot;
    int32_t initprot;
    uint32_t nsects;
    uint32_t flags;
} dsh_segment_command_64;

typedef struct {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t name_offset;
    uint32_t timestamp;
    uint32_t current_version;
    uint32_t compatibility_version;
} dsh_dylib_command;

static uint32_t dsh_bswap32(uint32_t v) {
    return ((v & 0x000000ffu) << 24) | ((v & 0x0000ff00u) << 8) |
           ((v & 0x00ff0000u) >> 8)  | ((v & 0xff000000u) >> 24);
}

static NSString *dsh_arch_name(uint32_t cputype, uint32_t cpusubtype) {
    uint32_t sub = cpusubtype & 0x00ffffffu;
    if (cputype == 0x0100000cu) {
        return (cpusubtype & 0x80000000u) ? @"arm64e" : (sub == 2 ? @"arm64 (A12)" : @"arm64");
    }
    if (cputype == 0x0000000cu) return @"arm (32)";
    if (cputype == 0x01000007u) return @"x86_64";
    return [NSString stringWithFormat:@"cpu 0x%x", cputype];
}

#pragma mark - 结果对象

@implementation DSHMachOReport

- (NSInteger)riskLevel {
    if (self.riskScore >= 60) return 2;
    if (self.riskScore >= 25) return 1;
    return 0;
}

- (NSString *)riskText {
    switch ([self riskLevel]) {
        case 2: return @"高度可疑";
        case 1: return @"值得留意";
        default: return @"未发现异常";
    }
}

@end

#pragma mark - 静态分析

// 从一段内存里提取所有长度 >= 4 的可打印 ASCII 串，逐个交给 block
static void dsh_foreach_string(const uint8_t *p, size_t len,
                               void (^block)(const char *buf, size_t slen)) {
    char acc[256];
    size_t used = 0;
    for (size_t i = 0; i < len; i++) {
        uint8_t c = p[i];
        if (c >= 0x20 && c <= 0x7e) {
            if (used < sizeof(acc) - 1) {
                acc[used++] = (char)c;
            }
        } else {
            if (used >= 4) {
                acc[used] = '\0';
                block(acc, used);
            }
            used = 0;
        }
    }
    if (used >= 4) {
        acc[used] = '\0';
        block(acc, used);
    }
}

// 公网看起来像的 IPv4（排除私有段与回环）
static BOOL dsh_looks_public_ip(const char *s) {
    int a = 0, b = 0, c = 0, d = 0;
    char tail = 0;
    if (sscanf(s, "%d.%d.%d.%d%c", &a, &b, &c, &d, &tail) != 4) return NO;
    if (a < 1 || a > 255) return NO;
    if (a == 10 || a == 127) return NO;
    if (a == 192 && b == 168) return NO;
    if (a == 172 && b >= 16 && b <= 31) return NO;
    if (a == 169 && b == 254) return NO;
    if (a == 0) return NO;
    return YES;
}

@implementation DSHMachO

+ (nullable DSHMachOReport *)analyzeFile:(NSString *)path maxBytes:(NSUInteger)maxBytes {
    if (path.length == 0) return nil;
    if (maxBytes == 0) maxBytes = 8 * 1024 * 1024;

    int fd = open(path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0) return nil;

    off_t total = lseek(fd, 0, SEEK_END);
    if (total <= 0) { close(fd); return nil; }
    lseek(fd, 0, SEEK_SET);

    size_t want = (size_t)MIN((off_t)maxBytes, total);
    uint8_t *buf = (uint8_t *)malloc(want);
    if (!buf) { close(fd); return nil; }

    size_t got = 0;
    while (got < want) {
        ssize_t n = read(fd, buf + got, want - got);
        if (n <= 0) break;
        got += (size_t)n;
    }
    close(fd);

    if (got < 32) { free(buf); return nil; }

    DSHMachOReport *rep = [DSHMachOReport new];
    rep.path = path;
    rep.fileName = path.lastPathComponent;
    rep.linkedLibraries = @[];
    rep.suspiciousSymbols = @[];
    rep.suspiciousStrings = @[];
    rep.reasons = @[];
    rep.riskScore = 0;

    // 1) 定位 Mach-O
    const uint8_t *base = buf;
    size_t avail = got;
    uint32_t be = dsh_bswap32(*(const uint32_t *)buf);
    if (be == DSH_FAT_MAGIC && got >= sizeof(dsh_fat_header) + sizeof(dsh_fat_arch)) {
        const dsh_fat_header *fh = (const dsh_fat_header *)buf;
        uint32_t n = dsh_bswap32(fh->nfat_arch);
        if (n == 0 || n > 16) { free(buf); return rep; }
        const dsh_fat_arch *fa = (const dsh_fat_arch *)(buf + sizeof(dsh_fat_header));
        uint32_t off = dsh_bswap32(fa->offset);
        uint32_t sz = dsh_bswap32(fa->size);
        if (off >= got) { free(buf); return rep; }
        base = buf + off;
        avail = MIN((size_t)sz, got - off);
    }

    if (avail < sizeof(dsh_mach_header_64)) { free(buf); return rep; }

    const dsh_mach_header_64 *mh = (const dsh_mach_header_64 *)base;
    if (mh->magic != DSH_MH_MAGIC_64 && mh->magic != DSH_MH_MAGIC) {
        free(buf);
        return rep;   // 不是 Mach-O
    }

    rep.isMachO = YES;
    rep.arch = dsh_arch_name(mh->cputype, mh->cpusubtype);
    rep.filetype = mh->filetype;

    // 2) 走一遍 load commands，拿链接库与 __TEXT 段范围
    NSMutableArray<NSString *> *libs = [NSMutableArray array];
    const uint8_t *textStart = NULL;
    size_t textLen = 0;

    size_t cursor = sizeof(dsh_mach_header_64);
    uint32_t ncmds = mh->ncmds;
    if (ncmds > 4096) ncmds = 4096;   // 防御坏文件

    for (uint32_t i = 0; i < ncmds; i++) {
        if (cursor + 8 > avail) break;
        const uint32_t *words = (const uint32_t *)(base + cursor);
        uint32_t cmd = words[0];
        uint32_t cmdsize = words[1];
        if (cmdsize < 8 || cursor + cmdsize > avail) break;

        if (cmd == DSH_LC_LOAD_DYLIB && cmdsize > sizeof(dsh_dylib_command)) {
            const dsh_dylib_command *dc = (const dsh_dylib_command *)(base + cursor);
            uint32_t nameOff = dc->name_offset;
            if (nameOff < cmdsize) {
                const char *name = (const char *)(base + cursor + nameOff);
                size_t maxLen = cmdsize - nameOff;
                size_t l = strnlen(name, maxLen);
                if (l > 0) {
                    NSString *s = [[NSString alloc] initWithBytes:name
                                                           length:l
                                                         encoding:NSUTF8StringEncoding];
                    if (s) [libs addObject:s];
                }
            }
        } else if (cmd == DSH_LC_SEGMENT_64 && cmdsize >= sizeof(dsh_segment_command_64)) {
            const dsh_segment_command_64 *seg = (const dsh_segment_command_64 *)(base + cursor);
            if (seg->segname[0] == '_' &&
                strncmp(seg->segname, "__TEXT", 16) == 0) {
                uint64_t fo = seg->fileoff;
                uint64_t fs = seg->filesize;
                if (fo < avail) {
                    textStart = base + fo;
                    textLen = (size_t)MIN(fs, (uint64_t)(avail - fo));
                }
            }
        }
        cursor += cmdsize;
    }

    rep.linkedLibraries = [libs copy];

    // 3) 扫字符串找可疑痕迹
    NSMutableArray<NSString *> *badStrings = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    __block NSInteger shellHits = 0;
    __block NSInteger netHits = 0;
    __block NSInteger credHits = 0;

    const uint8_t *scanP = textStart ? textStart : base;
    size_t scanLen = textStart ? textLen : avail;

    dsh_foreach_string(scanP, scanLen, ^(const char *buf, size_t slen) {
        NSString *str = [[NSString alloc] initWithBytes:buf
                                                 length:slen
                                               encoding:NSUTF8StringEncoding];
        if (!str) return;

        BOOL bad = NO;

        // shell 执行链
        if (strstr(buf, "-c ") || strstr(buf, "/bin/sh") || strstr(buf, "/bin/bash") ||
            strstr(buf, "base64 -d") || strstr(buf, "base64 -D") ||
            strstr(buf, "nc -e") || strstr(buf, "chmod 777") ||
            strstr(buf, "launchctl load") || strstr(buf, "launchctl bootout")) {
            if (![seen containsObject:str]) { shellHits++; [seen addObject:str]; bad = YES; }
        }
        // 下载 / 外联
        if (strstr(buf, "http://") || strstr(buf, "https://") ||
            strstr(buf, "curl ") || strstr(buf, "wget ")) {
            // 自己的更新检查之类很常见，只记一条
            if (netHits == 0 && ![seen containsObject:str]) { netHits++; [seen addObject:str]; bad = YES; }
        }
        // 直接摸凭据
        if (strstr(buf, "/etc/passwd") || strstr(buf, "/etc/shadow") ||
            strstr(buf, "/var/jb/etc/shadow")) {
            if (![seen containsObject:str]) { credHits++; [seen addObject:str]; bad = YES; }
        }
        // 裸公网 IP
        if (!bad && dsh_looks_public_ip(buf)) {
            if (![seen containsObject:str]) { netHits++; [seen addObject:str]; bad = YES; }
        }

        if (bad && badStrings.count < 24) {
            [badStrings addObject:str];
        }
    });

    // 4) 危险导入符号（从字符串池里能看出符号名，够用了）
    NSMutableArray<NSString *> *badSyms = [NSMutableArray array];
    NSArray<NSString *> *dangerous = @[ @"_system", @"_execve", @"_execvp", @"_posix_spawn",
                                        @"_posix_spawnp", @"_fork", @"_ptrace",
                                        @"_MSHookFunction", @"_MSHookMessageEx" ];
    dsh_foreach_string(base, avail, ^(const char *buf, size_t slen) {
        NSString *str = [[NSString alloc] initWithBytes:buf length:slen encoding:NSUTF8StringEncoding];
        if (!str) return;
        for (NSString *d in dangerous) {
            if (slen == d.length && strcmp(buf, d.UTF8String) == 0) {
                if (![badSyms containsObject:d]) [badSyms addObject:d];
                break;
            }
        }
    });

    rep.suspiciousSymbols = [badSyms copy];
    rep.suspiciousStrings = [badStrings copy];

    // 5) 算风险分
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    NSInteger score = 0;

    BOOL hasExec = [badSyms containsObject:@"_system"] ||
                   [badSyms containsObject:@"_execve"] ||
                   [badSyms containsObject:@"_execvp"] ||
                   [badSyms containsObject:@"_posix_spawn"] ||
                   [badSyms containsObject:@"_posix_spawnp"];
    if (hasExec) {
        score += 30;
        [reasons addObject:@"导入了进程执行符号（system / execve / posix_spawn），说明它会启动外部程序"];
    }
    if (hasExec && shellHits > 0) {
        score += 25;
        [reasons addObject:@"既有执行能力，又内嵌 shell 命令片段 —— 这是典型的下载执行模式"];
    }
    if (netHits > 0) {
        score += 20;
        [reasons addObject:@"含硬编码的网络地址（域名或公网 IP），可能用于回传或下载"];
    }
    if (credHits > 0) {
        score += 40;
        [reasons addObject:@"试图访问系统账号文件（/etc/passwd 或 /etc/shadow）"];
    }
    if ([badSyms containsObject:@"_ptrace"]) {
        score += 15;
        [reasons addObject:@"导入了 ptrace，可能用于反调试或注入别的进程"];
    }
    if ([badSyms containsObject:@"_MSHookFunction"] || [badSyms containsObject:@"_MSHookMessageEx"]) {
        score += 5;
        [reasons addObject:@"使用 Substrate/ellekit 的 hook 接口（tweak 属正常用法，仅作记录）"];
    }
    if (libs.count > 0) {
        for (NSString *l in libs) {
            if ([l containsString:@"CoreTelephony"] || [l containsString:@"CoreLocation"]) {
                score += 10;
                [reasons addObject:[NSString stringWithFormat:@"链接了隐私相关框架 %@", l.lastPathComponent]];
                break;
            }
        }
    }

    rep.riskScore = score;
    rep.reasons = [reasons copy];

    free(buf);
    return rep;
}

@end
