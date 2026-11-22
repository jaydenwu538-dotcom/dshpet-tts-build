// 自动生成（tools/gen_anim_table.js），勿手改。
#import "DSHPetAnimTable.h"

NSArray<NSString *> *DSHPetIdlePool(void) { return @[
    @"待机呼吸休闲"
  ]; }
NSArray<NSString *> *DSHPetTurnPool(void) { return @[
    @"东张西望"
  ]; }
NSArray<NSString *> *DSHPetDragPool(void) { return @[
    @"被鼠标拖拽悬空反馈"
  ]; }
NSArray<NSString *> *DSHPetClickPool(void) { return @[
    @"点击回应-开心跃动",
    @"点击回应-害羞惊讶",
    @"点击回应-傲娇生气",
    @"点击回应-挠痒咯咯笑",
    @"点击回应-元气挥手"
  ]; }
NSArray<NSString *> *DSHPetBalancePool(void) { return @[
    @"余额-钱袋满溢",
    @"余额-金袋叮当",
    @"余额-钱袋如常",
    @"余额-数金皱眉",
    @"余额-袋空如洗",
    @"余额-分文不剩"
  ]; }
NSArray<NSString *> *DSHPetWhisperPool(void) { return @[
    @"碎碎念-擦桌碎碎念",
    @"碎碎念-发呆碎碎念",
    @"碎碎念-对屏碎碎念"
  ]; }
NSArray<NSString *> *DSHPetWorkStatusPool(void) { return @[
    @"工作状态-思考冒泡",
    @"工作状态-忙碌点按",
    @"工作状态-清点归档",
    @"工作状态-原地踱步张望",
    @"工作状态-雀跃庆祝",
    @"工作状态-垂头叹气冒汗"
  ]; }
NSArray<NSString *> *DSHPetSleepStartPool(void) { return @[
    @"睡觉-开始"
  ]; }
NSArray<NSString *> *DSHPetSleepLoopPool(void) { return @[
    @"睡觉-循环"
  ]; }
NSArray<NSString *> *DSHPetSleepEndPool(void) { return @[
    @"睡觉-起来"
  ]; }

NSDictionary *DSHPetMoveDefaults(void) {
  return @{@"minDist": @60, @"maxDist": @240,
           @"margin": @20, @"leadSec": @2, @"tailSec": @2};
}

NSArray<NSDictionary *> *DSHPetMoves(void) {
  return @[
    @{@"name": @"螃蟹走路", @"minDist": @60, @"maxDist": @240, @"leadSec": @2, @"tailSec": @2, @"margin": @20},
    @{@"name": @"原地漂浮踏步", @"minDist": @40, @"maxDist": @120, @"leadSec": @2, @"tailSec": @2, @"margin": @20},
    @{@"name": @"原地左转奔跑", @"minDist": @120, @"maxDist": @320, @"leadSec": @1.75, @"tailSec": @4.8, @"margin": @20}
  ];
}

NSArray<NSDictionary *> *DSHPetCategories(void) {
  return @[
    @{@"id": @"小动作", @"weight": @20, @"noMirror": @(NO), @"actions": @[
      @"悠闲哼歌",
      @"超大伸懒腰",
      @"原地敲击桌面互动",
      @"原地重力下蹲压缩",
      @"哈欠连天",
      @"原地小憩沉眠",
      @"女仆屈膝礼仪",
      @"被吓一跳",
      @"小幅度原地360度旋转展示",
      @"偷吃零食被抓住",
      @"用鲸鱼尾巴拍打地面",
      @"打瞌睡被惊醒",
      @"照镜子",
      @"整体换装试色",
      @"轻快记录",
      @"写代码",
      @"摇扇纳凉",
      @"晨间刷牙"
    ]},
    @{@"id": @"玩耍", @"weight": @20, @"noMirror": @(NO), @"actions": @[
      @"原地专心玩魔方",
      @"原地蹲下玩玩具汽车",
      @"鲸鱼吐泡泡特效",
      @"原地跳跃抓碎头顶物品",
      @"玩游戏气急败坏",
      @"玩水枪",
      @"小提琴演奏",
      @"蓝鲸现世",
      @"优雅女仆舞",
      @"轻快摇摆舞",
      @"可爱宅舞",
      @"吹气球",
      @"动物环绕",
      @"放风筝",
      @"拆礼物",
      @"变鸽子",
      @"扑克魔术",
      @"抽陀螺",
      @"吹笛子",
      @"蝴蝶蜜蜂环绕头顶开花",
      @"撸猫",
      @"凭空生花",
      @"骑木马",
      @"三球抛接",
      @"踢毽子",
      @"下五子棋",
      @"荡秋千"
    ]},
    @{@"id": @"吃什么", @"weight": @16, @"noMirror": @(NO), @"actions": @[
      @"吃白饭",
      @"大口吃零食",
      @"吃Token",
      @"吃早餐",
      @"吃午餐",
      @"吃晚餐",
      @"吃冰淇淋融化",
      @"吃大闸蟹",
      @"吃糖葫芦",
      @"吃长寿面",
      @"吃西瓜",
      @"涮火锅"
    ]},
    @{@"id": @"时节", @"weight": @14, @"noMirror": @(NO), @"actions": @[
      @"被落叶淹没",
      @"中秋赏月吃月饼",
      @"堆雪人",
      @"放烟花",
      @"吃粽子",
      @"吃年糕",
      @"吃青团",
      @"吃腊八粥",
      @"吃重阳糕",
      @"收红包",
      @"写福字",
      @"穿针乞巧",
      @"舞狮头",
      @"讨糖南瓜灯",
      @"插茱萸赏菊",
      @"放河灯",
      @"萌化小幽灵",
      @"装点圣诞树",
      @"放孔明灯",
      @"吃汤圆",
      @"吃饺子"
    ]},
    @{@"id": @"文字", @"weight": @10, @"noMirror": @(YES), @"actions": @[
      @"是啊，吃什么",
      @"深度思考碎碎念"
    ]}
  ];
}

NSArray<NSString *> *DSHPetAllAnimations(void) {
  static NSArray<NSString *> *allList;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSMutableArray *a = [NSMutableArray array];
    for (NSArray *pool in @[DSHPetIdlePool(), DSHPetTurnPool(), DSHPetDragPool(), DSHPetClickPool(),
                            DSHPetBalancePool(), DSHPetWhisperPool(), DSHPetWorkStatusPool(),
                            DSHPetSleepStartPool(), DSHPetSleepLoopPool(), DSHPetSleepEndPool()]) {
      [a addObjectsFromArray:pool];
    }
    for (NSDictionary *mv in DSHPetMoves()) [a addObject:mv[@"name"]];
    for (NSDictionary *c in DSHPetCategories()) [a addObjectsFromArray:c[@"actions"]];
    allList = a;
  });
  return allList;
}

BOOL DSHPetIsNoMirror(NSString *name) {
  for (NSDictionary *c in DSHPetCategories()) {
    if ([c[@"noMirror"] boolValue] && [c[@"actions"] containsObject:name]) return YES;
  }
  return NO;
}

BOOL DSHPetIsMove(NSString *name) {
  for (NSDictionary *mv in DSHPetMoves()) if ([mv[@"name"] isEqualToString:name]) return YES;
  return NO;
}
