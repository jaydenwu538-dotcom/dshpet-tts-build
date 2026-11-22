//
//  DSHChat.m
//  DSHPet 安裝器
//

#import "DSHChat.h"
#import <spawn.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/wait.h>

// posix_spawn 需要环境变量表；<unistd.h> 会声明它，但 SDK 头里偶尔被隐藏掉
extern char **environ;

static NSString *const kDSHChatConfigFile = @"/var/mobile/Documents/DSHPet-chat.conf";
static NSString *const kDSHChatKeyFile = @"/var/mobile/Documents/DSHPet-chat.key";

@implementation DSHChatMessage

+ (instancetype)user:(NSString *)text {
    DSHChatMessage *m = [DSHChatMessage new];
    m.role = DSHChatRoleUser;
    m.text = text ?: @"";
    return m;
}

+ (instancetype)assistant:(NSString *)text {
    DSHChatMessage *m = [DSHChatMessage new];
    m.role = DSHChatRoleAssistant;
    m.text = text ?: @"";
    return m;
}

- (NSString *)roleName {
    return (self.role == DSHChatRoleAssistant) ? @"assistant" : @"user";
}

@end


@interface DSHChat ()
+ (NSString *)configPath;
+ (NSMutableDictionary *)loadConfig;
+ (void)saveConfig:(NSDictionary *)config;
@end

@implementation DSHChat

#pragma mark - 路径

+ (NSString *)configPath {
    // /var/mobile/Documents 在越獄機上對 mobile 可寫；寫不进去就退到临时目录
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [kDSHChatConfigFile stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        dir = NSTemporaryDirectory();
        return [dir stringByAppendingPathComponent:@"DSHPet-chat.conf"];
    }
    return kDSHChatConfigFile;
}

+ (NSString *)keyPath {
    NSString *dir = [[self configPath] stringByDeletingLastPathComponent];
    return [dir stringByAppendingPathComponent:@"DSHPet-chat.key"];
}

#pragma mark - 配置读写

+ (NSMutableDictionary *)loadConfig {
    NSData *data = [NSData dataWithContentsOfFile:[self configPath]];
    if (data.length) {
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if ([obj isKindOfClass:[NSDictionary class]]) return [obj mutableCopy];
    }
    return [NSMutableDictionary dictionary];
}

+ (void)saveConfig:(NSDictionary *)config {
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:0 error:NULL];
    if (!data) return;
    [data writeToFile:[self configPath] atomically:YES];
    // 只给当前用户读写，别让同机其他 App 顺手读到地址和提示词
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0600}
                                     ofItemAtPath:[self configPath]
                                            error:NULL];
}

+ (NSString *)stringForKey:(NSString *)key fallback:(NSString *)fallback {
    id v = [self loadConfig][key];
    if ([v isKindOfClass:[NSString class]] && [v length]) return v;
    return fallback;
}

+ (void)setString:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *cfg = [self loadConfig];
    if (value.length) cfg[key] = value;
    else [cfg removeObjectForKey:key];
    [self saveConfig:cfg];
}

+ (NSString *)baseURLString {
    return [self stringForKey:@"baseURL" fallback:@"https://api.deepseek.com"];
}

+ (void)setBaseURLString:(NSString *)value {
    [self setString:[self trimTrailingSlash:value] forKey:@"baseURL"];
}

+ (NSString *)modelName {
    return [self stringForKey:@"model" fallback:@"deepseek-chat"];
}

+ (void)setModelName:(NSString *)value {
    [self setString:value forKey:@"model"];
}

+ (NSString *)systemPrompt {
    return [self stringForKey:@"systemPrompt" fallback:@"你是手機桌面上的一隻小寵物，說話簡短、口語化、帶一點撒嬌，回覆控制在兩三句話以內。"];
}

+ (void)setSystemPrompt:(NSString *)value {
    [self setString:value forKey:@"systemPrompt"];
}

+ (NSString *)trimTrailingSlash:(NSString *)s {
    NSMutableString *m = [s mutableCopy] ?: [NSMutableString string];
    while ([m hasSuffix:@"/"]) [m deleteCharactersInRange:NSMakeRange(m.length - 1, 1)];
    return [m copy];
}

#pragma mark - API Key

+ (nullable NSString *)apiKey {
    NSString *path = [self keyPath];
    NSString *s = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return s.length ? s : nil;
}

+ (void)setAPIKey:(nullable NSString *)value {
    NSString *path = [self keyPath];
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        return;
    }
    [trimmed writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0600}
                                     ofItemAtPath:path
                                            error:NULL];
}

+ (BOOL)hasAPIKey {
    return [self apiKey] != nil;
}

+ (NSString *)endpointString {
    return [[self baseURLString] stringByAppendingString:@"/chat/completions"];
}

+ (BOOL)isConfigured {
    return [self hasAPIKey] && [self baseURLString].length > 0 && [self modelName].length > 0;
}

#pragma mark - 发请求

+ (void)sendMessages:(NSArray<DSHChatMessage *> *)messages
          completion:(void (^)(NSString *_Nullable, NSString *_Nullable))completion {
    void (^finish)(NSString *, NSString *) = ^(NSString *reply, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(reply, error);
        });
    };

    NSString *key = [self apiKey];
    if (!key.length) {
        finish(nil, @"還沒設定 API Key，先點右上角齒輪填一下。");
        return;
    }

    NSURL *url = [NSURL URLWithString:[self endpointString]];
    if (!url) {
        finish(nil, [NSString stringWithFormat:@"介面地址看不懂：%@", [self endpointString]]);
        return;
    }

    // 组装 messages：system 在最前，之后按顺序铺开历史
    NSMutableArray *wire = [NSMutableArray array];
    NSString *sys = [self systemPrompt];
    if (sys.length) [wire addObject:@{@"role": @"system", @"content": sys}];
    for (DSHChatMessage *m in messages) {
        if (!m.text.length) continue;
        [wire addObject:@{@"role": [m roleName], @"content": m.text}];
    }

    NSDictionary *body = @{@"model": [self modelName], @"messages": wire, @"stream": @NO};
    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    if (!payload) {
        finish(nil, @"要送出的內容組不起來。");
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 60.0;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = payload;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 60.0;
    cfg.timeoutIntervalForResource = 120.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    NSURLSessionDataTask *task =
        [session dataTaskWithRequest:req
                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                // 手机常态离线，这里最常见的就是没网
                NSString *msg = error.code == NSURLErrorNotConnectedToInternet
                    ? @"連不上網，先開一下 WiFi 或熱點。"
                    : [NSString stringWithFormat:@"請求失敗：%@", error.localizedDescription];
                finish(nil, msg);
                return;
            }

            NSInteger status = 0;
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                status = [(NSHTTPURLResponse *)response statusCode];
            }

            id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;

            if (status < 200 || status >= 300) {
                // 尽力把服务端的错误说明捞出来，比只报状态码有用
                NSString *detail = nil;
                if ([json isKindOfClass:[NSDictionary class]]) {
                    id err = json[@"error"];
                    if ([err isKindOfClass:[NSDictionary class]]) detail = err[@"message"];
                    else if ([err isKindOfClass:[NSString class]]) detail = err;
                    else if ([json[@"message"] isKindOfClass:[NSString class]]) detail = json[@"message"];
                }
                if (!detail.length && data.length) {
                    detail = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    if (detail.length > 300) detail = [detail substringToIndex:300];
                }
                if (!detail.length) detail = @"沒有附帶說明";
                finish(nil, [NSString stringWithFormat:@"服務端回 %ld：%@", (long)status, detail]);
                return;
            }

            NSString *content = nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                id choices = json[@"choices"];
                if ([choices isKindOfClass:[NSArray class]] && [choices count]) {
                    id first = choices[0];
                    if ([first isKindOfClass:[NSDictionary class]]) {
                        id msg = first[@"message"];
                        if ([msg isKindOfClass:[NSDictionary class]]) {
                            id c = msg[@"content"];
                            if ([c isKindOfClass:[NSString class]]) content = c;
                        }
                        // 有些实现不返回 message.content 而返回 text
                        if (!content.length) {
                            id t = first[@"text"];
                            if ([t isKindOfClass:[NSString class]]) content = t;
                        }
                    }
                }
            }

            content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!content.length) {
                finish(nil, @"回來的內容是空的，換個模型或介面試試。");
                return;
            }
            finish(content, nil);
        }];

    [task resume];
}

#pragma mark - 本地推理（llama.cpp）

static NSString *const kDSHChatDefaultModel = @"/var/jb/Library/DSHPet/models/qwen05-q4km.gguf";
static NSString *const kDSHChatDefaultSystem = @"你是手機桌面上的一隻小寵物，說話簡短、口語化，回覆控制在兩三句話以內。";

+ (NSString *)localBinaryPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candidates = @[@"/var/jb/usr/bin/llama-completion",
                                        @"/usr/bin/llama-completion"];
    for (NSString *p in candidates) {
        if ([fm isExecutableFileAtPath:p]) return p;
    }
    return candidates.firstObject ?: @"";
}

+ (NSString *)localModelPath {
    id saved = [self loadConfig][@"localModelPath"];
    if ([saved isKindOfClass:[NSString class]] && [saved length]) return saved;
    return kDSHChatDefaultModel;
}

+ (void)setLocalModelPath:(NSString *)value {
    NSMutableDictionary *c = [self loadConfig];
    NSString *v = [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (v.length) c[@"localModelPath"] = v;
    else [c removeObjectForKey:@"localModelPath"];
    [self saveConfig:c];
}

+ (DSHChatBackend)backend {
    id n = [self loadConfig][@"backend"];
    if ([n isKindOfClass:[NSNumber class]] && [n integerValue] == DSHChatBackendAPI) return DSHChatBackendAPI;
    return DSHChatBackendLocal;   // 預設吃本地模型：這台手機平時沒網
}

+ (void)setBackend:(DSHChatBackend)value {
    NSMutableDictionary *c = [self loadConfig];
    c[@"backend"] = @(value);
    [self saveConfig:c];
}

+ (BOOL)localBinaryAvailable {
    return [[NSFileManager defaultManager] isExecutableFileAtPath:[self localBinaryPath]];
}

+ (BOOL)localModelAvailable {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self localModelPath]];
}

+ (NSString *)localStatusText {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![self localBinaryAvailable]) return @"缺執行檔（重新安裝插件本體）";
    if (![self localModelAvailable]) return @"缺模型檔案";
    NSDictionary *attr = [fm attributesOfItemAtPath:[self localModelPath] error:NULL];
    unsigned long long size = [attr[NSFileSize] unsignedLongLongValue];
    return [NSString stringWithFormat:@"就緒・模型 %.0f MB", (double)size / 1024.0 / 1024.0];
}

// -st 的輸出會回顯 system/user/assistant 三段，取最後一個 assistant 之後的內容，
// 並去掉 "[end of text]" 與可能殘留的 ANSI 控制序列。
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

+ (void)sendLocalMessage:(NSString *)text
              completion:(void (^)(NSString *_Nullable, NSString *_Nullable))completion {
    void (^finish)(NSString *, NSString *) = ^(NSString *reply, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(reply, error); });
    };

    if (![text length]) { finish(nil, @"先打點字吧。"); return; }
    if (![self localBinaryAvailable]) {
        finish(nil, @"找不到 llama-completion。重裝一次插件本體，deb 會把它裝到 /var/jb/usr/bin/。");
        return;
    }
    if (![self localModelAvailable]) {
        finish(nil, @"找不到模型檔案。到設定裡把「模型路徑」指到 .gguf 的位置。");
        return;
    }

    NSString *bin = [self localBinaryPath];
    NSString *model = [self localModelPath];
    NSString *sys = [self systemPrompt];
    if (![sys length]) sys = kDSHChatDefaultSystem;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
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
            finish(nil, [NSString stringWithFormat:@"啟動推理程式失敗（posix_spawn rc=%d）", rc]);
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
            finish(nil, @"模型沒有給出內容。換個問法，或到設定裡換一個模型檔案。");
            return;
        }
        finish(reply, nil);
    });
}

@end
