#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 在 SpringBoard 進程內直接跑 llama-completion（不跳 App）。
// 模型與執行檔的預設路徑跟安裝器 App 保持一致，也可以被 App 寫的設定覆蓋。
@interface DSHPetChat : NSObject

+ (BOOL)available;
+ (nullable NSString *)unavailableReason;

// completion 一律在主線程回調。reply 與 error 只會有一個非 nil。
+ (void)ask:(NSString *)text completion:(void (^)(NSString *_Nullable reply, NSString *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
