#import "MVChatUser.h"
#import "MVChatUserPrivate.h"

#if defined(ENABLE_SILC) && ENABLE_SILC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#include <libsilcclient/client.h>
#include <libsilc/silcincludes.h>
#pragma clang diagnostic pop
#endif

NS_ASSUME_NONNULL_BEGIN

@class MVSILCChatConnection;

#if defined(ENABLE_SILC) && ENABLE_SILC
@interface MVSILCChatUser : MVChatUser {
	SilcClientEntry _clientEntry;
	BOOL _releasing;
}
- (id) initLocalUserWithConnection:(MVSILCChatConnection *) connection;
- (id) initWithClientEntry:(SilcClientEntry) clientEntry andConnection:(MVSILCChatConnection *) connection;
- (void) updateWithClientEntry:(SilcClientEntry) clientEntry;

- (SilcClientEntry) _getClientEntry;
@end
#endif

NS_ASSUME_NONNULL_END
