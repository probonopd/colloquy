/*
 * GrowlApplicationBridge.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Inert stub for the Growl notification framework.  The app falls back to
 * its own KABubble notifications when Growl is unavailable, so these methods
 * simply no-op.
 */

#ifndef GS_GROWL_BRIDGE_H
#define GS_GROWL_BRIDGE_H

#import <Foundation/Foundation.h>

// Growl notification dictionary keys and constants used by the app.
#define GROWL_APP_NAME @"ApplicationName"
#define GROWL_NOTIFICATION_NAME @"NotificationName"
#define GROWL_NOTIFICATION_TITLE @"NotificationTitle"
#define GROWL_NOTIFICATION_DESCRIPTION @"NotificationDescription"
#define GROWL_NOTIFICATION_ICON_DATA @"NotificationIconData"
#define GROWL_NOTIFICATION_IDENTIFIER @"NotificationIdentifier"
#define GROWL_NOTIFICATION_STICKY @"NotificationSticky"
#define GROWL_NOTIFICATION_PRIORITY @"NotificationPriority"
#define GROWL_NOTIFICATIONS_DEFAULT @"DefaultNotifications"
#define GROWL_NOTIFICATIONS_ALL @"AllNotifications"

@protocol GrowlApplicationBridgeDelegate <NSObject>
@optional
- (NSDictionary *) registrationDictionaryForGrowl;
@end

@interface GrowlApplicationBridge : NSObject
+ (void) setGrowlDelegate:(id <GrowlApplicationBridgeDelegate>)delegate;
+ (void) notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notificationName iconData:(NSData *)iconData priority:(int)priority isSticky:(BOOL)sticky clickContext:(id)context;
+ (void) notifyWithDictionary:(NSDictionary *)dictionary;
+ (BOOL) isGrowlRunning;
@end

#endif // GS_GROWL_BRIDGE_H