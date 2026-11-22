#import "DSHPetWindow.h"

@implementation DSHPetWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (!hit) return nil;

    if (self.petView && (hit == self.petView || [hit isDescendantOfView:self.petView])) {
        return hit;
    }
    if (self.menuView && (hit == self.menuView || [hit isDescendantOfView:self.menuView])) {
        return hit;
    }
    if (self.chatBubbleView && (hit == self.chatBubbleView || [hit isDescendantOfView:self.chatBubbleView])) {
        return hit;
    }
    return nil;
}

@end
