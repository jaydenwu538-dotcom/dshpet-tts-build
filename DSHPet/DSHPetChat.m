#import "DSHPetChat.h"
#import "DSHPetCommon.h"
#import <spawn.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/wait.h>
#import <string.h>

extern char **environ;

static NSString *const kDSHPetChatDefaultModel = @"/var/jb/Library/DSHPet/models/qwen05-q4km.gguf";
static NSString *const kDSHPetChatConfigPath = @"/var/mobile/Documents/DSHPet-chat.conf";
static NSString *const kDSHPetChatDefaultSystem = @"你是手機桌面上的一隻小寵物，說話簡短、口語化，回覆控制在兩三句話以內。";

@implementation DSHPetChat

+ (NSString *)binaryPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candidates = @[@"/var/jb/usr/bin/llama-completion",
                                        @"/usr/bin/llama-completion"];
    for (NSString *p in candidates) {
        if ([fm isExecutableFileAtPath:p]) return p;
    }
    return @"";
}

+ (NSDictionary *)config {
    NSData *data = [NSData dataWithContentsOfFile:kDSHPetChatConfigPath];
    if (![data length]) return @{};
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : @{};
}

+ (NSString *)modelPath {
    id saved = [self config][@"localModelPath"];
    if ([saved isKindOfClass:[NSString class]] && [saved length]) return saved;
    return kDSHPetChatDefaultModel;
}

+ (NSString *)systemPrompt {
    id saved = [self config][@"systemPrompt"];
    if ([saved isKindOfClass:[NSString class]] && [saved length]) return saved;
    return kDSHPetChatDefaultSystem;
}

+ (BOOL)available {
    return [self unavailableReason] == nil;
}

+ (NSString *)unavailableReason {
    if (![[self binaryPath] length]) return @"找不到 llama-completion，重裝一次插件本體。";
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self modelPath]]) return @"找不到模型檔案。";
    return nil;
}

// -st 會把 system / user / assistant 三段一起吐出來，取最後一個 assistant 之後的內容，
// 再去掉 [end of text] 與 ANSI 控制序列。
+ (NSString *)extractReplyFromRaw:(NSString *)raw {
    if (![raw length]) return @"";
    NSArray<NSString *> *parts = [raw componentsSeparatedByString:@"assistant\n"];
    NSString *body = [parts lastObject] ?: raw;
    NSRange end = [body rangeOfString:@"[end of text]"];
    if (end.location != NSNotFound) body = [body substringToIndex:end.location];

    NSMutableString *clean = [NSMutableString stringWithCapacity:[body length]];
    NSUInteger i = 0, n = [body length];
    while (i < n) {
        unichar ch = [body characterAtIndex:i];
        if (ch == 0x1B && i + 1 < n && [body characterAtIndex:i + 1] == '[') {
            i += 2;
            while (i < n) {
                unichar c2 = [body characterAtIndex:i++];
                if (c2 >= 0x40 && c2 <= 0x7E) break;
            }
            continue;
        }
        [clean appendFormat:@"%C", ch];
        i++;
    }
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (void)ask:(NSString *)text completion:(void (^)(NSString *, NSString *))completion {
    void (^finish)(NSString *, NSString *) = ^(NSString *reply, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(reply, error); });
    };

    if (![text length]) { finish(nil, @"先打點字吧。"); return; }
    NSString *reason = [self unavailableReason];
    if (reason) { finish(nil, reason); return; }

    NSString *bin = [self binaryPath];
    NSString *model = [self modelPath];
    NSString *sys = [self systemPrompt];

    // SpringBoard 是別人的進程，推理很吃 CPU，降到背景優先級免得把系統拖卡。
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int fds[2];
        if (pipe(fds) != 0) { finish(nil, @"pipe 建立失敗"); return; }

        const char *argv[] = {
            [bin fileSystemRepresentation],
            "-m", [model fileSystemRepresentation],
            "-sys", [sys UTF8String],
            "-p", [text UTF8String],
            "-n", "160",
            "-t", "4",
            "-st",
            "--no-warmup",
            NULL
        };

        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
        posix_spawn_file_actions_adddup2(&actions, fds[1], STDOUT_FILENO);
        posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
        posix_spawn_file_actions_addclose(&actions, fds[0]);
        posix_spawn_file_actions_addclose(&actions, fds[1]);

        pid_t pid = 0;
        int rc = posix_spawn(&pid, [bin fileSystemRepresentation], &actions, NULL, (char *const *)argv, environ);
        posix_spawn_file_actions_destroy(&actions);
        close(fds[1]);

        if (rc != 0) {
            close(fds[0]);
            finish(nil, [NSString stringWithFormat:@"啟動推理程式失敗（rc=%d）", rc]);
            return;
        }

        NSMutableData *buf = [NSMutableData data];
        char chunk[8192];
        ssize_t got = 0;
        while ((got = read(fds[0], chunk, sizeof(chunk))) > 0) {
            [buf appendBytes:chunk length:(NSUInteger)got];
        }
        close(fds[0]);

        int status = 0;
        waitpid(pid, &status, 0);

        NSString *raw = [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];
        NSString *reply = [self extractReplyFromRaw:raw ?: @""];
        if (![reply length]) {
            finish(nil, @"模型沒有給出內容。換個問法試試。");
            return;
        }
        DSHPetTrace(@"chat: reply %lu chars", (unsigned long)[reply length]);
        finish(reply, nil);
    });
}

@end
