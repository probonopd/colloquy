/*
 * test_join.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Headless backend test: connect to an IRC server, join a room, and send a
 * message, so the connection path can be exercised without the GUI.
 *
 *   test_join [server [port [room]]]
 *
 * Defaults to irc.libera.chat:6697 over TLS and #gershwin.  A plain-text
 * server (port other than 6697, or CQ_TLS=0) is used as-is, which is what the
 * local test server in the build instructions runs on.  SASL_PASSWORD enables
 * SASL authentication.
 *
 * Exits 0 only if the connection came up, the room was joined and a message
 * could be sent to it.
 *
 * Sending goes through the attributed-string to IRC-format conversion, which
 * asks NSFontManager about the run's traits, so the tool needs the AppKit
 * backend and therefore a display (run it under Xvfb).
 */

@class NSScriptObjectSpecifier;
#import <Foundation/Foundation.h>
#import <Foundation/NSScriptObjectSpecifiers.h>
#import <AppKit/AppKit.h>
#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVIRCChatConnection.h"

static int didConnect = 0;
static int didJoin = 0;

static void runUntil(BOOL *flag, NSTimeInterval seconds) {
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow: seconds];
	while ((!flag || !*flag) && [[NSDate date] compare: end] == NSOrderedAscending)
		[[NSRunLoop mainRunLoop] runMode: NSDefaultRunLoopMode beforeDate: end];
}

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		// The chat-format conversion needs the AppKit backend; see above.
		[NSApplication sharedApplication];

		NSString *server = (argc > 1) ? @(argv[1]) : @"irc.libera.chat";
		unsigned short port = (argc > 2) ? (unsigned short)atoi(argv[2]) : 6697;
		NSString *roomName = (argc > 3) ? @(argv[3]) : @"gershwin";

		const char *tlsEnv = getenv("CQ_TLS");
		BOOL secure = tlsEnv ? (atoi(tlsEnv) != 0) : (port == 6697);

		MVIRCChatConnection *connection = [[MVIRCChatConnection alloc] init];
		if (!connection) { NSLog(@"FAIL: alloc"); return 1; }

		connection.server = server;
		connection.serverPort = port;
		connection.secure = secure;
		NSString *nick = [NSString stringWithFormat: @"cq_%@", [[[NSUUID UUID] UUIDString] substringToIndex: 8]];
		connection.nickname = nick;
		connection.username = @"colognustep";
		connection.realName = @"Colloquy GNUstep";

		NSString *saslPass = @(getenv("SASL_PASSWORD") ?: "");
		if (saslPass.length) {
			connection.requestsSASL = YES;
			connection.nicknamePassword = saslPass;
			NSLog(@"SASL enabled for nick=%@", nick);
		} else {
			connection.requestsSASL = NO;
		}

		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

		[center addObserverForName: MVChatConnectionDidConnectNotification object: connection queue: nil
		                usingBlock: ^(NSNotification *note) {
			didConnect = 1;
			NSLog(@"connected to %@:%u (secure=%d)", server, (unsigned)port, (int)[connection didConnectSecurely]);
			[connection joinChatRoomNamed: roomName];
		}];

		[center addObserverForName: MVChatConnectionDidNotConnectNotification object: connection queue: nil
		                usingBlock: ^(NSNotification *note) {
			didConnect = -1;
			NSLog(@"FAIL: did not connect: %@", note.userInfo[@"error"]);
		}];

		[center addObserverForName: MVChatConnectionErrorNotification object: connection queue: nil
		                usingBlock: ^(NSNotification *note) {
			NSLog(@"connection error: %@", note.userInfo);
		}];

		[center addObserverForName: MVChatRoomJoinedNotification object: nil queue: nil
		                usingBlock: ^(NSNotification *note) {
			didJoin = 1;
			NSLog(@"joined %@", [[note object] name]);
		}];

		[center addObserverForName: MVChatRoomGotMessageNotification object: nil queue: nil
		                usingBlock: ^(NSNotification *note) {
			NSLog(@"message in %@: %@", [[note object] name], note.userInfo[@"message"]);
		}];

		[connection connect];

		BOOL connected = NO;
		NSDate *end = [NSDate dateWithTimeIntervalSinceNow: 25.0];
		while (didConnect == 0 && [[NSDate date] compare: end] == NSOrderedAscending)
			[[NSRunLoop mainRunLoop] runMode: NSDefaultRunLoopMode beforeDate: end];
		connected = (didConnect == 1);
		if (!connected) { NSLog(@"FAIL: no connection"); return 1; }

		runUntil(NULL, 10.0);
		if (!didJoin) { NSLog(@"FAIL: room %@ was not joined", roomName); [connection disconnect]; return 1; }

		MVChatRoom *room = [connection joinedChatRoomWithName: roomName];
		if (!room) { NSLog(@"FAIL: no room object for %@", roomName); [connection disconnect]; return 1; }

		// Sending exercises the chat-string conversion the GUI uses: the Mac
		// build passes attributed strings all the way into the IRC encoder.
		NSAttributedString *message = [[NSAttributedString alloc] initWithString: @"colloquy gnustep test message"];
		[room sendMessage: message withEncoding: [connection encoding] asAction: NO];
		runUntil(NULL, 3.0);

		NSLog(@"PASS: connected, joined %@ and sent a message", roomName);
		[connection disconnect];
		runUntil(NULL, 1.0);
		return 0;
	}
}
