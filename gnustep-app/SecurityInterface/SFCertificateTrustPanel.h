/*
 * SFCertificateTrustPanel.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Inert stub for the SecurityInterface certificate trust panel.  GNUstep
 * always trusts (see the Chat Core SecTrust stubs), so this panel is never
 * presented; the class exists so the upstream sources compile.
 */

#ifndef GS_SFCERTIFICATETRUSTPANEL_H
#define GS_SFCERTIFICATETRUSTPANEL_H

#import <Foundation/Foundation.h>

@class NSWindow;

@interface SFCertificateTrustPanel : NSPanel
+ (SFCertificateTrustPanel *) sharedCertificateTrustPanel;
@property (nonatomic) BOOL showsHelp;
- (void) setAlternateButtonTitle:(NSString *)title;
- (void) setDefaultButtonTitle:(NSString *)title;
- (NSInteger) runModalForTrust:(void *)trust showGroup:(BOOL)showGroup;
- (void) beginSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo trust:(void *)trust showGroup:(BOOL)showGroup;
- (void) setInformativeText:(NSString *)text;
- (void) setMessageText:(NSString *)text;
@end

#endif // GS_SFCERTIFICATETRUSTPANEL_H