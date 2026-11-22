//
//  DSHChat.h
//  DSHPet 安裝器
//
//  手機端的簡短對話：把一輪 messages POST 到 OpenAI 相容的 /chat/completions。
//  介面參考使用者舊作 AI1.9.ipa（AIFloatingAssistant）的 AIChatManager，
//  但那邊用 @AppStorage 存 apiKey（明文落在 plist 裡），這裡改成獨立檔案 + 0600 權限。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSHChatRole) {
    DSHChatRoleUser = 0,
    DSHChatRoleAssistant,
};

@interface DSHChatMessage : NSObject
@property (nonatomic, assign) DSHChatRole role;
@property (nonatomic, copy) NSString *text;
+ (instancetype)user:(NSString *)text;
+ (instancetype)assistant:(NSString *)text;
// 发给服务端时用的 "user" / "assistant"
- (NSString *)roleName;
@end

@interface DSHChat : NSObject

// 介面地址，例如 https://api.openai.com/v1 或 https://api.deepseek.com
+ (NSString *)baseURLString;
+ (void)setBaseURLString:(NSString *)value;

// 模型名，例如 gpt-4o-mini / deepseek-chat
+ (NSString *)modelName;
+ (void)setModelName:(NSString *)value;

// 系统提示词，为空时用内置的桌面宠人格
+ (NSString *)systemPrompt;
+ (void)setSystemPrompt:(NSString *)value;

// API Key：不放 NSUserDefaults，单独存文件并 chmod 0600
+ (nullable NSString *)apiKey;
+ (void)setAPIKey:(nullable NSString *)value;
+ (BOOL)hasAPIKey;

// 配置是否完整到可以发请求
+ (BOOL)isConfigured;

// 发一轮对话。messages 只需要带 user/assistant，system 由内部补。
// completion 一定在主线程回调，二者必有其一为 nil。
+ (void)sendMessages:(NSArray<DSHChatMessage *> *)messages
          completion:(void (^)(NSString *_Nullable reply, NSString *_Nullable error))completion;

// 拼出来的完整端点，设置页用来给用户确认
+ (NSString *)endpointString;

// 推理方式：本地 llama.cpp（离线跑 0.5B 小模型）或 OpenAI 兼容 API
typedef NS_ENUM(NSInteger, DSHChatBackend) {
    DSHChatBackendLocal = 0,
    DSHChatBackendAPI,
};

+ (DSHChatBackend)backend;
+ (void)setBackend:(DSHChatBackend)value;

// 本地推理：執行檔與模型都由 deb 一起安裝，模型路徑可在設定頁改
+ (NSString *)localBinaryPath;
+ (NSString *)localModelPath;
+ (void)setLocalModelPath:(nullable NSString *)value;
+ (BOOL)localBinaryAvailable;
+ (BOOL)localModelAvailable;
// 給人看的一句話狀態：能用 / 缺執行檔 / 缺模型
+ (NSString *)localStatusText;

// 本地跑一次單輪對話。completion 一定回主執行緒，二者必有其一為 nil。
+ (void)sendLocalMessage:(NSString *)text
              completion:(void (^)(NSString *_Nullable reply, NSString *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
