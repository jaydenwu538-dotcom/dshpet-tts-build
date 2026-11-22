#import "DSHPetPhysics.h"
#import "DSHPetCommon.h"

const CGFloat DSHPetGravity = 1400.0;
const CGFloat DSHPetRestitution = 0.78;
const CGFloat DSHPetGroundFriction = 2.5;
const CGFloat DSHPetRestNormal = 40.0;
const CGFloat DSHPetRestTangent = 15.0;
const CGFloat DSHPetRestNormalEps = 1.0;
const CGFloat DSHPetMaxStepDT = 0.05;
const CGFloat DSHPetMaxThrowSpeed = 3600.0;
const CGFloat DSHPetSubstepPx = 8.0;
const CGFloat DSHPetSquashMax = 0.55;
const CGFloat DSHPetSpringK = 200.0;
const CGFloat DSHPetSpringC = 30.0;

CGPoint DSHPetContactVelocity(CGPoint v, CGPoint n, CGFloat restitution, CGFloat friction, CGFloat dt) {
    CGFloat tx = -n.y;
    CGFloat ty = n.x;
    CGFloat vn = v.x * n.x + v.y * n.y;
    CGFloat vt = v.x * tx + v.y * ty;
    CGFloat normalSpeed = (fabs(vn) < DSHPetRestNormal) ? 0.0 : fabs(vn) * restitution;
    CGFloat tangentSpeed = vt * fmax(0.0, 1.0 - friction * dt);
    return CGPointMake(normalSpeed * n.x + tangentSpeed * tx,
                       normalSpeed * n.y + tangentSpeed * ty);
}

CGFloat DSHPetSoftClampSpeed(CGFloat v) {
    return DSHPetMaxThrowSpeed * (1.0 - exp(-v / DSHPetMaxThrowSpeed));
}

CGFloat DSHPetLandingSquash(CGFloat impact) {
    CGFloat t = DSHPetClamp((fabs(impact) - 300.0) / (1500.0 - 300.0), 0.0, 1.0);
    return 1.0 - t * (1.0 - DSHPetSquashMax);
}

CGFloat DSHPetSquashScale(CGFloat u, CGFloat squash) {
    u = DSHPetClamp(u, 0.0, 1.0);
    if (u < 0.45) {
        CGFloat k = u / 0.45;
        return 1.0 - (1.0 - squash) * k * k;
    }
    CGFloat p = (u - 0.45) / 0.55;
    const CGFloat c1 = 1.70158;
    const CGFloat c3 = 2.70158;
    CGFloat f = 1.0 + c3 * pow(p - 1.0, 3) + c1 * pow(p - 1.0, 2);
    return fmin(1.12, squash + (1.0 - squash) * fmax(f, 0.0));
}

int DSHPetSubsteps(CGPoint v, CGFloat dt) {
    CGFloat travel = hypot(v.x, v.y) * DSHPetClamp(dt, 0.0, DSHPetMaxStepDT);
    if (travel <= DSHPetSubstepPx) return 1;
    int n = (int)ceil(travel / DSHPetSubstepPx);
    return n < 1 ? 1 : (n > 64 ? 64 : n);
}

CGPoint DSHPetSpringStep(CGPoint pos, CGPoint *vel, CGPoint target, CGFloat k, CGFloat c, CGFloat power, CGFloat dt) {
    CGFloat ax = (target.x - pos.x) * k - vel->x * c;
    CGFloat ay = (target.y - pos.y) * k - vel->y * c;
    vel->x += ax * power * dt;
    vel->y += ay * power * dt;
    return CGPointMake(pos.x + vel->x * dt, pos.y + vel->y * dt);
}
