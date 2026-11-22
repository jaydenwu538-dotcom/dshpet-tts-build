#import "DSHPetAppDelegate.h"
#import "DSHPetMainViewController.h"
#import "DSHChatViewController.h"

@implementation DSHPetAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    DSHPetMainViewController *root = [[DSHPetMainViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    nav.navigationBar.prefersLargeTitles = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

- (UINavigationController *)navController {
    UIViewController *root = self.window.rootViewController;
    if ([root isKindOfClass:[UINavigationController class]]) return (UINavigationController *)root;
    return nil;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    // 桌寵長按菜單裡的「聊聊天」走 dshpet://chat 進來，直接開對話頁。
    if (![[url scheme] isEqualToString:@"dshpet"]) return NO;
    UINavigationController *nav = [self navController];
    if (!nav) return NO;
    if ([[url host] isEqualToString:@"chat"]) {
        [nav popToRootViewControllerAnimated:NO];
        for (UIViewController *vc in nav.viewControllers) {
            if ([vc isKindOfClass:[DSHChatViewController class]]) {
                [nav popToViewController:vc animated:NO];
                return YES;
            }
        }
        [nav pushViewController:[DSHChatViewController new] animated:NO];
        return YES;
    }
    return NO;
}

@end
