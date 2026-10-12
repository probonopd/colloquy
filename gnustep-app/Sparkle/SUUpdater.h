/*
 * SUUpdater.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Inert stub for the Sparkle update framework.  GNUstep has no software
 * update service; the class exists so the upstream sources compile and the
 * "Check for Updates" action no-ops.
 */

#ifndef GS_SPARKLE_SUUPDATER_H
#define GS_SPARKLE_SUUPDATER_H

#import <Foundation/Foundation.h>

@interface SUUpdater : NSObject
+ (SUUpdater *) sharedUpdater;
- (void) checkForUpdates:(id)sender;
- (void) checkForUpdatesInBackground;
- (void) setAutomaticallyChecksForUpdates:(BOOL)flag;
- (BOOL) automaticallyChecksForUpdates;
- (void) setUpdateCheckInterval:(NSTimeInterval)interval;
- (NSTimeInterval) updateCheckInterval;
@end

#endif // GS_SPARKLE_SUUPDATER_H