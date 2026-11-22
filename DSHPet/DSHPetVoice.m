#import "DSHPetVoice.h"
#import "DSHPetCommon.h"
#import <AVFoundation/AVFoundation.h>

static NSString *const kDSHPetVoiceFlag = @"/var/jb/Library/DSHPet/voice";
static NSString *const kDSHPetVoiceFlagAlt = @"/Library/DSHPet/voice";

@interface DSHPetVoiceImpl : NSObject <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) AVSpeechSynthesizer *synth;
@property (nonatomic) BOOL audioConfigured;
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
    if (self.synth.isSpeaking) [self.synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

    AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:text];
    // 優先挑中文語音；找不到就用系統預設。
    AVSpeechSynthesisVoice *zh = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    if (!zh) zh = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-TW"];
    if (zh) u.voice = zh;
    u.rate = 0.48;            // 0.5 是預設速度，稍微降一點聽起來更像撒嬌
    u.pitchMultiplier = 1.12; // 音調略高，貼近小寵物的人設
    u.volume = 0.95;
    [self.synth speakUtterance:u];
    DSHPetTrace(@"voice: speaking %lu chars", (unsigned long)[text length]);
}

- (void)stop {
    if (self.synth.isSpeaking) [self.synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
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

+ (void)speak:(NSString *)text {
    if (![self enabled]) return;
    [[DSHPetVoiceImpl shared] speak:text];
}

+ (void)stop {
    [[DSHPetVoiceImpl shared] stop];
}

@end
