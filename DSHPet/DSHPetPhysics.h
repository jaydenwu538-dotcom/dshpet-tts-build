#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <math.h>

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat DSHPetGravity;
extern const CGFloat DSHPetRestitution;
extern const CGFloat DSHPetGroundFriction;
extern const CGFloat DSHPetRestNormal;
extern const CGFloat DSHPetRestTangent;
extern const CGFloat DSHPetRestNormalEps;
extern const CGFloat DSHPetMaxStepDT;
extern const CGFloat DSHPetMaxThrowSpeed;
extern const CGFloat DSHPetSubstepPx;
extern const CGFloat DSHPetSquashMax;
extern const CGFloat DSHPetSpringK;
extern const CGFloat DSHPetSpringC;

/** 拖拽松手后的接触响应：n 为外法线。 */
CGPoint DSHPetContactVelocity(CGPoint v, CGPoint n, CGFloat restitution, CGFloat friction, CGFloat dt);

CGFloat DSHPetSoftClampSpeed(CGFloat v);

/** 落地冲击速度 -> 挤压比例（0.55 ~ 1.0）。 */
CGFloat DSHPetLandingSquash(CGFloat impact);

/** 挤压动画第 u（0~1）帧的 scaleY。 */
CGFloat DSHPetSquashScale(CGFloat u, CGFloat squash);

int DSHPetSubsteps(CGPoint v, CGFloat dt);

/** 一步弹簧积分，返回新位置，速度写回 *vel。 */
CGPoint DSHPetSpringStep(CGPoint pos, CGPoint *vel, CGPoint target, CGFloat k, CGFloat c, CGFloat power, CGFloat dt);

NS_ASSUME_NONNULL_END
