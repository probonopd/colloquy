@class NSScriptObjectSpecifier;
/*
 * test_smoke.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Minimal smoke test for the ported Colloquy Chat Core: instantiate an IRC
 * connection, exercise the API, and run the runloop briefly to make sure the
 * threading/socket shims don't crash.
 */

#import <Foundation/Foundation.h>
#import "MVChatConnection.h"
#import "MVIRCChatConnection.h"

static int didConnect = 0;

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		MVIRCChatConnection *connection = [[MVIRCChatConnection alloc] init];
		if (!connection) {
			NSLog(@"FAIL: could not allocate MVIRCChatConnection");
			return 1;
		}

		connection.server = @"127.0.0.1";
		connection.serverPort = 6667;
		connection.nickname = @"colognustep";
		connection.username = @"colognustep";
		connection.realName = @"Colloquy GNUstep";
		connection.password = nil;

		NSLog(@"connection: %@ type=%lu urlScheme=%@",
		      [connection description], (unsigned long)[connection type], [connection urlScheme]);
		NSLog(@"supported encodings present: %d", ([connection supportedStringEncodings] != NULL));

		[[NSNotificationCenter defaultCenter] addObserverForName: MVChatConnectionDidConnectNotification
		                                                  object: connection
		                                                   queue: nil
		                                              usingBlock: ^(NSNotification *note) {
			didConnect = 1;
			NSLog(@"did connect: %@", note.name);
			[connection disconnect];
		}];

		[[NSNotificationCenter defaultCenter] addObserverForName: MVChatConnectionDidNotConnectNotification
		                                                  object: connection
		                                                   queue: nil
		                                              usingBlock: ^(NSNotification *note) {
			didConnect = -1;
			NSLog(@"did not connect (expected: no IRC server listening): %@", note.userInfo[@"error"]);
		}];

		[connection connect];
		NSLog(@"connection status after connect: %lu", (unsigned long)[connection status]);

		// Run the runloop until the deadline to exercise the socket shim
		// threads.  runMode:beforeDate: returns as soon as a single event is
		// processed, so loop until the deadline actually elapses.
		NSDate *end = [NSDate dateWithTimeIntervalSinceNow: 5.0];
		while (didConnect == 0 && [[NSDate date] compare: end] == NSOrderedAscending) {
			[[NSRunLoop mainRunLoop] runMode: NSDefaultRunLoopMode beforeDate: end];
		}

		NSLog(@"didConnect=%d", didConnect);
		[connection disconnect];
		NSLog(@"smoke test complete");
		return 0;
	}
}
