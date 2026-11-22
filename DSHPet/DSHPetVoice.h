#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 桌寵的「嗓子」。第一版直接用系統的 AVSpeechSynthesizer（離線、零體積、中文可選），
// 之後若要換成本地 TTS 模型，只需要換這裡的實現，調用方不用動。
@interface DSHPetVoice : NSObject

+ (BOOL)enabled;
+ (void)setEnabled:(BOOL)enabled;

// 會先停掉上一句話。text 為空時等於 stop。
+ (void)speak:(NSString *)text;
+ (void)stop;

@end

NS_ASSUME_NONNULL_END
