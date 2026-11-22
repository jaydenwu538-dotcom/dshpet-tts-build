#import "DSHPetVoice.h"
#import "DSHPetCommon.h"
#import <AVFoundation/AVFoundation.h>
#import <spawn.h>
#import <unistd.h>
#import <sys/wait.h>

extern char **environ;

static NSString *const kDSHPetVoiceFlag = @"/var/jb/Library/DSHPet/voice";
static NSString *const kDSHPetVoiceFlagAlt = @"/Library/DSHPet/voice";

// 本地 TTS 工具（sherpa-onnx 命令行）与 fanchen-C 中文女声模型。
// 有它们就用自然得多的合成音，没有就退回系统 AVSpeechSynthesizer。
static NSString *const kDSHPetTTSModelDir = @"/var/jb/Library/DSHPet/models/fanchen";
// 语速倍率：小于 1 = 更快更尖，贴着「小宠物」的人设。fanchen-C 本身偏慢，给 0.85。
static NSString *const kDSHPetTTSLengthScale = @"0.85";

static NSString *DSHPetTTSTool(void) {
    NSArray<NSString *> *cands = @[
        @"/var/jb/usr/bin/sherpa-tts",
        @"/var/jb/usr/bin/sherpa-tts-ci2",
        @"/usr/bin/sherpa-tts",
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in cands) {
        if ([fm isExecutableFileAtPath:p]) return p;
    }
    return nil;
}

static BOOL DSHPetLocalTTSAvailable(void) {
    if (!DSHPetTTSTool()) return NO;
    NSString *onnx = [kDSHPetTTSModelDir stringByAppendingPathComponent:@"model.int8.onnx"];
    return [[NSFileManager defaultManager] fileExistsAtPath:onnx];
}

@interface DSHPetVoiceImpl : NSObject <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) AVSpeechSynthesizer *synth;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic) BOOL audioConfigured;
@property (nonatomic) pid_t ttsPid;
@end

@implementation DSHPetVoiceImpl

+ (instancetype)shared {
    static DSHPetVoiceImpl *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[DSHPetVoiceImpl alloc] init]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        _synth = [[AVSpeechSynthesizer alloc] init];
        _synth.delegate = self;
        _ttsPid = -1;
    }
    return self;
}

// SpringBoard 進程裡沒有現成的 audio session，要自己開一個「混音」session，
// 這樣念台詞不會把使用者在聽的音樂掐掉。
- (void)configureAudioIfNeeded {
    if (self.audioConfigured) return;
    self.audioConfigured = YES;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [session setCategory:AVAudioSessionCategoryAmbient error:&err];
    if (err) DSHPetTrace(@"voice: setCategory failed %@", err.localizedDescription);
    err = nil;
    [session setActive:YES error:&err];
    if (err) DSHPetTrace(@"voice: setActive failed %@", err.localizedDescription);
}

- (void)speak:(NSString *)text {
    if (![text length]) { [self stop]; return; }
    [self configureAudioIfNeeded];
    if (DSHPetLocalTTSAvailable()) {
        [self speakLocal:text];
    } else {
        [self speakSystem:text];
    }
}

// 用 sherpa-tts 命令行在後台合成 wav，完成後再用 AVAudioPlayer 播。
// 合成在 QOS_CLASS_USER_INITIATED 隊列裡跑，不阻塞主線程（SpringBoard 卡住會被 watchdog 殺）。
- (void)speakLocal:(NSString *)text {
    NSString *tool = DSHPetTTSTool();
    NSString *dir = kDSHPetTTSModelDir;
    NSString *wav = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"dshpet-tts-%d.wav", (int)getpid()]];
    [[NSFileManager defaultManager] removeItemAtPath:wav error:NULL];

    DSHPetTrace(@"voice: local synth %lu chars", (unsigned long)[text length]);
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        const char *bin = [tool UTF8String];
        const char *argv[] = {
            bin,
            [dir UTF8String],
            [text UTF8String],
            [wav UTF8String],
            [kDSHPetTTSLengthScale UTF8String],
            NULL
        };
        posix_spawn_file_actions_t fa;
        posix_spawn_file_actions_init(&fa);
        // 子進程的輸出全部丟掉，避免管道堵住導致死等
        posix_spawn_file_actions_addopen(&fa, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
        posix_spawn_file_actions_addopen(&fa, STDERR_FILENO, "/dev/null", O_WRONLY, 0);

        pid_t pid = 0;
        int rc = posix_spawn(&pid, bin, &fa, NULL, (char *const *)argv, environ);
        posix_spawn_file_actions_destroy(&fa);

        BOOL ok = NO;
        if (rc == 0) {
            int status = 0;
            waitpid(pid, &status, 0);
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:wav error:NULL];
            ok = [attrs[NSFileSize] unsignedLongLongValue] > 1024;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [weakSelf playWav:wav];
            } else {
                DSHPetTrace(@"voice: local synth failed rc=%d, fallback to system tts", rc);
                [weakSelf speakSystem:text];
            }
        });
    });
}

- (void)playWav:(NSString *)path {
    [self configureAudioIfNeeded];
    [self.player stop];
    self.player = nil;
    NSError *err = nil;
    AVAudioPlayer *p = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                             error:&err];
    if (!p) {
        DSHPetTrace(@"voice: player init failed %@", err.localizedDescription);
        return;
    }
    p.volume = 0.95;
    p.enableRate = YES;
    p.rate = 1.05;   // 稍微快一點，聽起來更活潑
    self.player = p;
    [p play];
    DSHPetTrace(@"voice: playing wav %@", path.lastPathComponent);
}

- (void)speakSystem:(NSString *)text {
    if (self.synth.isSpeaking) [self.synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:text];
    // 優先挑中文語音；找不到就用系統預設。
    AVSpeechSynthesisVoice *zh = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    if (!zh) zh = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-TW"];
    if (zh) u.voice = zh;
    u.rate = 0.48;
    u.pitchMultiplier = 1.12;
    u.volume = 0.95;
    [self.synth speakUtterance:u];
    DSHPetTrace(@"voice: system tts %lu chars", (unsigned long)[text length]);
}

- (void)stop {
    if (self.synth.isSpeaking) [self.synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    if (self.player.isPlaying) [self.player stop];
    self.player = nil;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    DSHPetTrace(@"voice: finished");
}

@end

@implementation DSHPetVoice

+ (BOOL)enabled {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:kDSHPetVoiceFlag]) return YES;
    if ([fm fileExistsAtPath:kDSHPetVoiceFlagAlt]) return YES;
    return NO;
}

+ (void)setEnabled:(BOOL)enabled {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = kDSHPetVoiceFlag;
    if (![fm fileExistsAtPath:@"/var/jb/Library/DSHPet"] && [fm fileExistsAtPath:@"/Library/DSHPet"]) {
        path = kDSHPetVoiceFlagAlt;
    }
    if (enabled) {
        [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent]
      withIntermediateDirectories:YES attributes:nil error:NULL];
        [@"1" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    } else {
        [fm removeItemAtPath:path error:NULL];
        [[DSHPetVoiceImpl shared] stop];
    }
}

+ (BOOL)localAvailable {
    return DSHPetLocalTTSAvailable();
}

+ (void)speak:(NSString *)text {
    if (![self enabled]) return;
    [[DSHPetVoiceImpl shared] speak:text];
}

+ (void)stop {
    [[DSHPetVoiceImpl shared] stop];
}

@end
