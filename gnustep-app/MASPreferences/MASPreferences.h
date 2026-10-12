/*
 * MASPreferences.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Minimal GNUstep implementation of the MASPreferences window-controller API
 * used by Colloquy.  Upstream implements this as a window with a toolbar of
 * view-controller icons that switch the content view; this shim reproduces
 * that behavior with standard GNUstep AppKit classes.
 */

#ifndef GS_MASPREFERENCES_H
#define GS_MASPREFERENCES_H

#import <Cocoa/Cocoa.h>

@protocol MASPreferencesViewController <NSObject>
@optional
@property (nonatomic, readonly) BOOL hasResizableHeight;
@property (nonatomic, readonly) BOOL hasOptionsButton;
// Cocoa's NSViewController answers -identifier through
// NSUserInterfaceItemIdentification; GNUstep's does not, so the category in
// MASPreferences.m answers the pane's -viewIdentifier instead.
- (NSString *) identifier;
@required
@property (nonatomic, readonly) NSString *viewIdentifier;
@property (nonatomic, readonly) NSImage *toolbarItemImage;
@property (nonatomic, readonly) NSString *toolbarItemLabel;
@end

@class MASPreferencesViewController;

@interface MASPreferencesWindowController : NSWindowController <NSToolbarDelegate, NSWindowDelegate>
{
@private
	NSMutableArray<NSViewController<MASPreferencesViewController> *> *_viewControllers;
	NSViewController<MASPreferencesViewController> *_currentViewController;
	NSToolbar *_toolbar;
	NSDictionary *_toolbarItems;
	CGFloat _paneWidth;
}

- (instancetype) initWithViewControllers:(NSArray<NSViewController<MASPreferencesViewController> *> *)viewControllers;

@property (nonatomic, readonly) NSArray<NSViewController<MASPreferencesViewController> *> *viewControllers;

// Plug-in preference panes are appended after the window was created.
- (void) addViewController:(NSViewController<MASPreferencesViewController> *)viewController;

- (void) selectControllerAtIndex:(NSUInteger)index;
- (void) selectControllerWithIdentifier:(NSString *)identifier;

@property (nonatomic, readonly) NSViewController<MASPreferencesViewController> *currentViewController;

@end

#endif // GS_MASPREFERENCES_H