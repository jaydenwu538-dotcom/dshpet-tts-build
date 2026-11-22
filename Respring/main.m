// dshpet-respring —— 由 deb 的 postinst 安装为 setuid root 的「小管家」。
//
// 用法：
//   dshpet-respring                    重启 SpringBoard
//   dshpet-respring install <tar.gz>   把 app 内置的 payload 解到 /var/jb（一键安装）
//   dshpet-respring uninstall          删掉插件本体（保留模型与动画以外的东西）
//
// 为什么要它：TrollStore 装的 App 以 mobile 身份跑，写不了 /var/jb。
// 有了这个 setuid 助手，App 才能在不依赖 Sileo/dpkg 的情况下自己装插件。
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>

extern char **environ;

static NSString *const kJB = @"/var/jb";

static int run(const char *path, char *const argv[]) {
    if (access(path, X_OK) != 0) return -1;
    pid_t pid = 0;
    int rc = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (rc != 0) return rc;
    int status = 0;
    waitpid(pid, &status, 0);
    return status;
}

static void respring(void) {
    char *sbreload_jb[] = { (char *)"/var/jb/usr/bin/sbreload", NULL };
    char *sbreload_sys[] = { (char *)"/usr/bin/sbreload", NULL };
    char *kill_jb[] = { (char *)"/var/jb/usr/bin/killall", (char *)"-9", (char *)"SpringBoard", NULL };
    char *kill_sys[] = { (char *)"/usr/bin/killall", (char *)"-9", (char *)"SpringBoard", NULL };

    if (access(sbreload_jb[0], X_OK) == 0) { run(sbreload_jb[0], sbreload_jb); return; }
    if (access(sbreload_sys[0], X_OK) == 0) { run(sbreload_sys[0], sbreload_sys); return; }
    if (access(kill_jb[0], X_OK) == 0) { run(kill_jb[0], kill_jb); return; }
    if (access(kill_sys[0], X_OK) == 0) { run(kill_sys[0], kill_sys); return; }
    fprintf(stderr, "no respring tool found\n");
}

// 递归改属主与权限：目录 755，可执行文件 755，其余 644。
static void fix_ownership(NSString *root) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *en = [fm enumeratorAtPath:root];
    chown([root fileSystemRepresentation], 0, 0);
    chmod([root fileSystemRepresentation], 0755);
    for (NSString *rel in en) {
        NSString *full = [root stringByAppendingPathComponent:rel];
        const char *p = [full fileSystemRepresentation];
        struct stat st;
        if (lstat(p, &st) != 0) continue;
        chown(p, 0, 0);
        if (S_ISDIR(st.st_mode)) {
            chmod(p, 0755);
        } else if (S_ISREG(st.st_mode) && (st.st_mode & S_IXUSR)) {
            chmod(p, 0755);
        } else if (S_ISREG(st.st_mode)) {
            chmod(p, 0644);
        }
    }
}

// 越狱分区里的可执行文件必须签名并进 trustcache，否则内核以 Killed: 9 拒绝执行。
static void sign_and_trust(NSString *path) {
    if (access(path.fileSystemRepresentation, F_OK) != 0) return;
    NSString *ldid = nil;
    for (NSString *c in @[@"/var/jb/usr/bin/ldid", @"/usr/bin/ldid", @"/usr/bin/ldid2"]) {
        if (access(c.fileSystemRepresentation, X_OK) == 0) { ldid = c; break; }
    }
    if (!ldid) return;

    char *s1[] = { (char *)ldid.fileSystemRepresentation, (char *)"-S",
                   (char *)path.fileSystemRepresentation, NULL };
    run(s1[0], s1);

    // 取真 cdhash：ldid -h 打印的 CandidateCDHash sha256=<40 hex>，FAT 会有两行，只用第一行
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *fh = pipe.fileHandleForReading;
    pid_t pid = 0;
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&fa, pipe.fileHandleForReading.fileDescriptor);
    char *s2[] = { (char *)ldid.fileSystemRepresentation, (char *)"-h",
                   (char *)path.fileSystemRepresentation, NULL };
    if (posix_spawn(&pid, s2[0], &fa, NULL, s2, environ) == 0) {
        [pipe.fileHandleForWriting closeFile];
        NSData *out = [fh readDataToEndOfFile];
        int status = 0;
        waitpid(pid, &status, 0);
        NSString *text = [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            if (![line hasPrefix:@"CandidateCDHash sha256="]) continue;
            NSString *cd = [line substringFromIndex:@"CandidateCDHash sha256=".length];
            cd = [cd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (cd.length != 40) break;
            if (access("/var/jb/basebin/jbctl", X_OK) == 0) {
                char *s3[] = { (char *)"/var/jb/basebin/jbctl", (char *)"trustcache", (char *)"add",
                               (char *)cd.UTF8String, NULL };
                run(s3[0], s3);
            }
            break;
        }
    } else {
        [pipe.fileHandleForWriting closeFile];
    }
    posix_spawn_file_actions_destroy(&fa);
    [fh closeFile];
}

// 解压 payload 到 /var/jb。payload 由 App 传入绝对路径（在 app 容器里，App 自己可读）。
static int cmd_install(const char *payload) {
    if (access(payload, R_OK) != 0) {
        fprintf(stderr, "payload not readable: %s\n", payload);
        return 2;
    }
    NSString *tar = nil;
    for (NSString *c in @[@"/usr/bin/tar", @"/var/jb/usr/bin/tar", @"/bin/tar"]) {
        if (access(c.fileSystemRepresentation, X_OK) == 0) { tar = c; break; }
    }
    if (!tar) { fprintf(stderr, "no tar found\n"); return 3; }

    printf("extracting %s -> %s\n", payload, kJB.UTF8String);
    char *argv[] = { (char *)tar.fileSystemRepresentation, (char *)"-xzf", (char *)payload,
                     (char *)"-C", (char *)kJB.fileSystemRepresentation, NULL };
    int rc = run(argv[0], argv);
    if (rc != 0) { fprintf(stderr, "tar failed rc=%d\n", rc); return 4; }

    fix_ownership(kJB);

    // respring 助手自身要保持 setuid，且不能被 fix_ownership 改坏
    NSString *helper = @"/var/jb/usr/bin/dshpet-respring";
    if (access(helper.fileSystemRepresentation, F_OK) == 0) {
        chown(helper.fileSystemRepresentation, 0, 0);
        chmod(helper.fileSystemRepresentation, 04755);
        sign_and_trust(helper);
    }
    sign_and_trust(@"/var/jb/usr/bin/llama-completion");
    sign_and_trust(@"/var/jb/usr/bin/sherpa-tts");
    sign_and_trust(@"/var/jb/Library/DSHPet/lib/SherpaOnnxC.framework/SherpaOnnxC");

    // 资源目录放开写权限，方便 App 之后原地更新
    NSString *assets = @"/var/jb/Library/DSHPet";
    if (access(assets.fileSystemRepresentation, F_OK) == 0) {
        chmod(assets.fileSystemRepresentation, 0777);
        NSString *mov = [assets stringByAppendingPathComponent:@"mov"];
        if (access(mov.fileSystemRepresentation, F_OK) == 0) {
            chmod(mov.fileSystemRepresentation, 0777);
        }
    }

    printf("installed ok\n");
    respring();
    return 0;
}

static int cmd_uninstall(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *targets = @[
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/DSHPet.dylib",
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/DSHPet.plist",
    ];
    for (NSString *t in targets) {
        [fm removeItemAtPath:t error:NULL];
    }
    printf("removed plugin; assets and models kept\n");
    respring();
    return 0;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        // 关键：setuid 程序里 real uid 仍是 mobile，exec 会落回它。
        // 只有 euid==0 时 setuid(0) 才能把 real/saved 一起提上来。
        if (geteuid() == 0 && getuid() != 0) {
            setuid(0);
        }

        if (argc >= 2 && strcmp(argv[1], "install") == 0) {
            if (argc < 3) { fprintf(stderr, "usage: dshpet-respring install <tar.gz>\n"); return 2; }
            return cmd_install(argv[2]);
        }
        if (argc >= 2 && strcmp(argv[1], "uninstall") == 0) {
            return cmd_uninstall();
        }
        printf("respring\n");
        respring();
        return 0;
    }
}
