#import "JVAnalyticsController.h"

// Colloquy's analytics collector uses IOKit, sysctl and the MAC address to
// build a machine fingerprint.  None of that exists on GNUstep, and analytics
// are opt-in (JVAllowAnalytics) in the upstream code.  Stub the controller out
// so the calls in MVApplicationController and MVConnectionsController compile
// and no-op.

@implementation JVAnalyticsController
+ (JVAnalyticsController *) defaultController {
	return nil;
}

- (id) objectForKey:(NSString *) key { (void)key; return nil; }

- (void) setObject:(id) object forKey:(NSString *) key { (void)object; (void)key; }

- (void) synchronizeSoon {}
- (void) synchronize {}
- (void) synchronizeSynchronously {}
@end