//
//  DSHMachO.h
//  ｜静态体检：不运行可疑文件，只读它的结构与字符串
//
//  为什么不做「沙箱里跑一下看行为」：iOS 没有对第三方开放的虚拟化，
//  越狱环境里的 dylib 一旦加载就是 root 权限、直接注入 SpringBoard，
//  没有任何用户态手段能把它关进笼子里。所以在真机上唯一安全的方向是静态分析：
//  看它链接了哪些库、导入了哪些危险符号、内嵌了哪些域名/命令，
//  这些信息足够判断一个 tweak 是「正常功能」还是「想干坏事」。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSHMachOReport : NSObject

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, assign) BOOL isMachO;
@property (nonatomic, copy) NSString *arch;
@property (nonatomic, assign) uint32_t filetype;
@property (nonatomic, copy) NSArray<NSString *> *linkedLibraries;
@property (nonatomic, copy) NSArray<NSString *> *suspiciousSymbols;
@property (nonatomic, copy) NSArray<NSString *> *suspiciousStrings;
@property (nonatomic, copy) NSArray<NSString *> *reasons;
@property (nonatomic, assign) NSInteger riskScore;

// 0 = 看着正常 / 1 = 值得留意 / 2 = 高度可疑
- (NSInteger)riskLevel;
- (NSString *)riskText;

@end

@interface DSHMachO : NSObject

// 只读文件前面 maxBytes 字节（默认 8 MB），越狱机上一个 tweak 很少超过这个量级
+ (nullable DSHMachOReport *)analyzeFile:(NSString *)path maxBytes:(NSUInteger)maxBytes;

@end

NS_ASSUME_NONNULL_END
