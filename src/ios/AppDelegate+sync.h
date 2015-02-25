#import "AppDelegate.h"

@interface AppDelegate (sync)

- (id) getCommandInstance:(NSString *)className;
- (void) backgroundSyncSetup:(NSNotification *)notification;

@end