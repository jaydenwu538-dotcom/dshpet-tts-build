//
//  DSHSecurity.h
//  安全体检：全部只读，不动系统文件。
//
//  iOS 上没有「病毒库 + 实时监控」那套东西，能做的是一件更实在的事：
//  把这台机器暴露出来的攻击面摊开给你看 —— 谁在开机自启、SSH 是不是敞着、
//  装进来的每个 dylib 到底链接了什么、想执行什么命令。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSHSeverity) {
    DSHSeverityInfo = 0,      // 只是告知
    DSHSeverityWarn = 1,      // 建议处理
    DSHSeverityCritical = 2,  // 应当立刻处理
};

@interface DSHFinding : NSObject

@property (nonatomic, assign) DSHSeverity severity;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy, nullable) NSString *path;
@property (nonatomic, copy) NSArray<NSString *> *evidence;
@property (nonatomic, copy, nullable) NSString *fixHint;

+ (instancetype)findingWithSeverity:(DSHSeverity)sev
                           category:(NSString *)category
                              title:(NSString *)title
                             detail:(NSString *)detail;

- (NSString *)severityText;

@end

@interface DSHSecurity : NSObject

// 同步执行，调用方必须放在后台线程（会做文件 IO 与 dylib 扫描）
+ (NSArray<DSHFinding *> *)runAllChecks;

+ (NSString *)reportTextForFindings:(NSArray<DSHFinding *> *)findings;

// 单项检查（方便分阶段展示）
+ (NSArray<DSHFinding *> *)checkExposure;
+ (NSArray<DSHFinding *> *)checkStartupItems;
+ (NSArray<DSHFinding *> *)checkTweaks;
+ (NSArray<DSHFinding *> *)checkInstallers;

@end

NS_ASSUME_NONNULL_END
