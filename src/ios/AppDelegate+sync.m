#import "AppDelegate+sync.h"
#import "CDVBackgroundSync.h"
#import "CDVServiceWorker.h"
#import <objc/runtime.h>

@implementation AppDelegate (sync)

CDVBackgroundSync *backgroundSync;

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundSyncSetup:) name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
    return [self swizzled_init];
}

- (void)backgroundSyncSetup:(NSNotification *)notification {
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    backgroundSync = [self getCommandInstance:@"BackgroundSync"];
    [backgroundSync restoreRegistrations];
    backgroundSync.serviceWorker = [self getCommandInstance:@"ServiceWorker"];;
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    [backgroundSync fetchNewDataWithCompletionHandler:completionHandler];
}
@end
