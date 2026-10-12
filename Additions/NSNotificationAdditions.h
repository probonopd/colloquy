NS_ASSUME_NONNULL_BEGIN

@interface NSNotificationCenter (NSNotificationCenterAdditions)
+ (NSNotificationCenter *) chatCenter;

- (void) postNotificationOnMainThread:(NSNotification *) notification;
- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait;

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id _Nullable) object;
- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id _Nullable) object userInfo:(NSDictionary * _Nullable) userInfo;
- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id _Nullable) object userInfo:(NSDictionary * _Nullable) userInfo waitUntilDone:(BOOL) wait;
@end

NS_ASSUME_NONNULL_END
