#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 桌寵的「嗓子」。優先走本地 sherpa-onnx + Piper 小模型（自然得多），
// 找不到工具或模型時自動退回系統 AVSpeechSynthesizer。
@interface DSHPetVoice : NSObject

+ (BOOL)enabled;
+ (void)setEnabled:(BOOL)enabled;

// 本地 TTS（sherpa-tts + piper_low 模型）是否就绪
+ (BOOL)localAvailable;

// 會先停掉上一句話。text 為空時等於 stop。
+ (void)speak:(NSString *)text;
+ (void)stop;

@end

NS_ASSUME_NONNULL_END
