#import "AppDelegate+sync.h"
#import "CDVBackgroundSync.h"
#import <objc/runtime.h>

@implementation AppDelegate (sync)

- (id)getCommandInstance:(NSString *)className {
    return [self.viewController getCommandInstance:className];
}

// Set up method swizzling in load call
+ (void)load {
    Method original, swizzled;
    
    original = class_getInstanceMethod(self, @selector(init));
    swizzled = class_getInstanceMethod(self, @selector(swizzled_init));
    method_exchangeImplementations(original, swizzled);
}

- (AppDelegate *)swizzled_init {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registerBackgroundFetch:) name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
    return [self swizzled_init];
}

- (void)registerBackgroundFetch:(NSNotification *)notification {
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    CDVBackgroundSync *backgroundSync = [self getCommandInstance:@"BackgroundSync"];
    [backgroundSync fetchNewDataWithCompletionHandler:completionHandler];
}



@end