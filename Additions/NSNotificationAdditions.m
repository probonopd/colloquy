#import "NSNotificationAdditions.h"
#import <pthread.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSNotificationCenter (NSNotificationCenterAdditions)
+ (NSNotificationCenter *) chatCenter {
#if ENABLE(CHAT_CENTER)
	static NSNotificationCenter *chatCenter = nil;
	static dispatch_once_t onceToken;
	CQQueueOnce(&onceToken, ^{
		chatCenter = [[NSNotificationCenter alloc] init];
	});
	return chatCenter;
#else
	return [NSNotificationCenter defaultCenter];
#endif
}
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	if( [NSThread isMainThread] ) [self postNotification:notification];
	else [self postNotificationOnMainThread:notification waitUntilDone:NO];
}

- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait {
	if( [NSThread isMainThread] ) [self postNotification:notification];
	else {
		// GNUstep's performSelectorOnMainThread: marshals the argument object
		// across the Distributed Objects connection, which corrupts the
		// userInfo (JVChatMessage, MVChatRoom, etc. do not survive the
		// serialization). Schedule on the main run loop instead, which only
		// retains the argument.
		[[NSRunLoop mainRunLoop] performSelector:@selector( _postNotification: ) target:[self class] argument:@{ @"notification": notification, @"center": self } order:0 modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	}
}

+ (void) _postNotification:(NSDictionary *) info {
	NSNotification *_Nonnull notification = (NSNotification *_Nonnull)info[@"notification"];
	[info[@"center"] postNotification:notification];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id _Nullable) object {
	if( [NSThread isMainThread] ) [self postNotificationName:name object:object userInfo:nil];
	else [self postNotificationOnMainThreadWithName:name object:object userInfo:@{} waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id _Nullable) object userInfo:(NSDictionary * _Nullable ) userInfo {
	if( [NSThread isMainThread] ) [self postNotificationName:name object:object userInfo:userInfo];
	else [self postNotificationOnMainThreadWithName:name object:object userInfo:userInfo waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id _Nullable) object userInfo:(NSDictionary * _Nullable ) userInfo waitUntilDone:(BOOL) wait {
	if( [NSThread isMainThread] ) [self postNotificationName:name object:object userInfo:userInfo];
		else {
		if ( !name ) return;
		NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:3];
		info[@"name"] = name;

		if( object ) info[@"object"] = object;
		if( userInfo ) info[@"userInfo"] = userInfo;
		info[@"center"] = self;

		// GNUstep's performSelectorOnMainThread: marshals the argument across
		// Distributed Objects and corrupts the userInfo. Schedule on the main
		// run loop, which only retains the argument.
		[[NSRunLoop mainRunLoop] performSelector:@selector( _postNotificationName: ) target:[self class] argument:info order:0 modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	}
}

+ (void) _postNotificationName:(NSDictionary *) info {
	NSString *_Nonnull name = (NSString *_Nonnull)info[@"name"];
	[info[@"center"] postNotificationName:name object:info[@"object"] userInfo:info[@"userInfo"]];
}
@end

NS_ASSUME_NONNULL_END
