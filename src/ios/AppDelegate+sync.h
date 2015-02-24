#import "AppDelegate.h"

@interface AppDelegate (sync)

- (id) getCommandInstance:(NSString *)className;
- (void) registerBackgroundFetch:(NSNotification *)notification;

@end