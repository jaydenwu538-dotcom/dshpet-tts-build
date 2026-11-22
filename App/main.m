#import <UIKit/UIKit.h>
#import <unistd.h>
#import <fcntl.h>
#import <signal.h>
#import <string.h>
#import <stdio.h>
#import <execinfo.h>
#import "DSHPetAppDelegate.h"

// 崩溃现场留下线索：App 若在启动阶段崩溃，用户可从下面的文件里读到原因。
// 优先 /var/mobile/Documents（TrollStore 安装时通常可写），退回 App 自己的 tmp。
static int gCrashFd = -1;

static NSString *DSHCrashLogPath(void) {
    NSArray<NSString *> *candidates = @[
        @"/var/mobile/Documents/DSHPet-crash.log",
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"DSHPet-crash.log"]
    ];
    for (NSString *p in candidates) {
        int fd = open(p.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            gCrashFd = fd;
            return p;
        }
    }
    return nil;
}

static void DSHWriteRaw(const char *text) {
    if (gCrashFd < 0 || !text) return;
    write(gCrashFd, text, strlen(text));
    fsync(gCrashFd);
}

static void DSHSignalHandler(int signo) {
    char buf[512];
    snprintf(buf, sizeof(buf), "\n[CRASH] signal %d (%s)\n", signo,
             signo == SIGSEGV ? "SIGSEGV" :
             signo == SIGBUS  ? "SIGBUS" :
             signo == SIGABRT ? "SIGABRT" :
             signo == SIGILL  ? "SIGILL" :
             signo == SIGFPE  ? "SIGFPE" : "?");
    DSHWriteRaw(buf);

    void *frames[32];
    int count = backtrace(frames, 32);
    char **symbols = backtrace_symbols(frames, count);
    if (symbols) {
        for (int i = 0; i < count; i++) {
            DSHWriteRaw("  ");
            DSHWriteRaw(symbols[i]);
            DSHWriteRaw("\n");
        }
        free(symbols);
    }

    // 交回系统默认处理，好让系统也生成一份 .ips 崩溃报告。
    signal(signo, SIG_DFL);
    raise(signo);
}

static void DSHExceptionHandler(NSException *exception) {
    char buf[2048];
    snprintf(buf, sizeof(buf), "\n[EXCEPTION] %s: %s\n  %s\n",
             exception.name.UTF8String ?: "?",
             exception.reason.UTF8String ?: "?",
             exception.callStackSymbols.description.UTF8String ?: "-");
    DSHWriteRaw(buf);
}

static void DSHInstallCrashHandlers(void) {
    NSString *path = DSHCrashLogPath();
    if (!path) return;
    char head[512];
    snprintf(head, sizeof(head), "\n===== DSHPet launch %s =====\n",
             [[[NSDate date] description] UTF8String] ?: "-");
    DSHWriteRaw(head);

    NSSetUncaughtExceptionHandler(&DSHExceptionHandler);
    for (int sig = 1; sig < 32; sig++) {
        if (sig == SIGKILL || sig == SIGSTOP) continue;
        signal(sig, DSHSignalHandler);
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        DSHInstallCrashHandlers();
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DSHPetAppDelegate class]));
    }
}
