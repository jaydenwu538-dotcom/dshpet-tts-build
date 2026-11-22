#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSHState) {
    DSHStateUnknown = 0,
    DSHStateOK,
    DSHStateWarn,
    DSHStateBad,
};

@interface DSHStatusItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy, nullable) NSString *note;
@property (nonatomic) DSHState state;
+ (instancetype)title:(NSString *)title value:(NSString *)value note:(nullable NSString *)note state:(DSHState)state;
@end

/** 越狱环境探测 / 安装状态 / respring / 诊断报告。 */
@interface DSHPetDiagnostics : NSObject

/** App 能否直接看到越狱根目录（TrollStore 安装的无沙盒 App 为 YES）。 */
+ (BOOL)hasJailbreakAccess;

/** 系统里的动画素材数量。 */
+ (NSInteger)installedAssetCount;

/** 逐项状态，用于列表展示。 */
+ (NSArray<DSHStatusItem *> *)statusItems;

/** 纯文本诊断报告，可直接分享。 */
+ (NSString *)reportText;

/** App 内嵌的 deb（Resources/DSHPet.deb）。 */
+ (nullable NSURL *)bundledDebURL;
+ (nullable NSURL *)preparedDebURL;

/** 用 deb 的 postinst 装好的 setuid 助手重启 SpringBoard。 */
+ (BOOL)respring;

#pragma mark - 一键安装（不经过 Sileo）

/** setuid 助手 /var/jb/usr/bin/dshpet-respring 是否就位。第一次装必须靠 deb，之后就能一键。 */
+ (BOOL)helperInstalled;

/** App 内嵌的安装负载（Resources/payload.tar.gz 或 payload_light.tar.gz）。 */
+ (nullable NSURL *)bundledPayloadURL;

/** 调助手把 payload 解到 /var/jb，顺带签名 + trustcache + respring。
 *  会阻塞十几秒，务必在后台队列调用。 */
+ (BOOL)installViaHelper:(nullable NSString *)payloadPath;
+ (BOOL)uninstallViaHelper;

/** 桌宠当前是否开启（读 /var/jb/Library/DSHPet/disabled）。 */
+ (BOOL)petEnabled;

/** 切换桌宠开关，立即通过 Darwin notification 通知 SpringBoard，不需要 respring。返回操作后的实际状态。 */
+ (BOOL)setPetEnabled:(BOOL)enabled;

/** 插件本体（DSHPet.dylib）是否已装到位。 */
+ (BOOL)pluginInstalled;

/** 把报告写成 /var/mobile/Documents/<prefix>-<时间>.txt，返回路径。
 *  走文件而不是 ShareSheet，因为 UIActivityViewController 在这台越狱机上会崩在系统内部。 */
+ (nullable NSString *)writeReportFile:(NSString *)text prefix:(NSString *)prefix;

@end

NS_ASSUME_NONNULL_END
