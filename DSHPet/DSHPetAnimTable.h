// 自动生成（tools/gen_anim_table.js），勿手改。
#import <Foundation/Foundation.h>

extern NSArray<NSString *> *DSHPetIdlePool(void);
extern NSArray<NSString *> *DSHPetTurnPool(void);
extern NSArray<NSString *> *DSHPetDragPool(void);
extern NSArray<NSString *> *DSHPetClickPool(void);
extern NSArray<NSString *> *DSHPetBalancePool(void);
extern NSArray<NSString *> *DSHPetWhisperPool(void);
extern NSArray<NSString *> *DSHPetWorkStatusPool(void);
extern NSArray<NSString *> *DSHPetSleepStartPool(void);
extern NSArray<NSString *> *DSHPetSleepLoopPool(void);
extern NSArray<NSString *> *DSHPetSleepEndPool(void);
/** 分类池：每项 {id, weight, noMirror, actions}。 */
extern NSArray<NSDictionary *> *DSHPetCategories(void);
/** 移动动作：每项 {name, minDist, maxDist, leadSec, tailSec, margin}（已合并 default）。 */
extern NSArray<NSDictionary *> *DSHPetMoves(void);
extern NSDictionary *DSHPetMoveDefaults(void);
/** 全部动作名（用于菜单点播与校验）。 */
extern NSArray<NSString *> *DSHPetAllAnimations(void);
/** 动画名是否属于文字类（noMirror）。 */
extern BOOL DSHPetIsNoMirror(NSString *name);
/** 该动作是否属于移动池。 */
extern BOOL DSHPetIsMove(NSString *name);
