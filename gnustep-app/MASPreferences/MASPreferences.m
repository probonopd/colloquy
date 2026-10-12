/*
 * MASPreferences.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep implementation of the MASPreferences window-controller shim.
 */

#import <MASPreferences/MASPreferences.h>

// GNUstep's NSViewController does not adopt NSUserInterfaceItemIdentification,
// so preference panes have no -identifier of their own.  They all answer
// -viewIdentifier, which is the identifier the window controller selects by.
@implementation NSViewController (MASPreferencesIdentifier)
- (NSString *) identifier {
	if ([self respondsToSelector:@selector(viewIdentifier)])
		return [(id <MASPreferencesViewController>)self viewIdentifier];
	return nil;
}
@end

@implementation MASPreferencesWindowController

- (instancetype) initWithViewControllers:(NSArray<NSViewController<MASPreferencesViewController> *> *)viewControllers {
	// The window is built in code; GNUstep's -initWithWindowNibName: rejects a
	// nil nib name, so hand the window to the designated initializer instead.
	NSRect contentRect = NSMakeRect(0, 0, 640, 480);
	NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
		styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
		backing:NSBackingStoreBuffered defer:YES];
	[window setReleasedWhenClosed:NO];
	[window setTitle:NSLocalizedString(@"Preferences", @"Preferences window title")];
	[window setMinSize:NSMakeSize(320, 240)];

	if (!(self = [super initWithWindow:window]))
		return nil;

	_viewControllers = [viewControllers mutableCopy];
	_toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:viewControllers.count];

	[window setDelegate:self];

	_toolbar = [[NSToolbar alloc] initWithIdentifier:@"ColloquyPreferencesToolbar"];
	[_toolbar setDelegate:self];
	[_toolbar setAllowsUserCustomization:NO];
	[_toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[_toolbar setSizeMode:NSToolbarSizeModeRegular];
	[_toolbar setAutosavesConfiguration:NO];
	[window setToolbar:_toolbar];

	if (viewControllers.count)
		[self selectControllerAtIndex:0];

	return self;
}

- (NSArray<NSViewController<MASPreferencesViewController> *> *) viewControllers {
	return [_viewControllers copy];
}

- (void) addViewController:(NSViewController<MASPreferencesViewController> *)viewController {
	if (!viewController) return;
	[_viewControllers addObject:viewController];
	// The toolbar asks the delegate for its identifiers, so rebuilding it is
	// what makes the new pane appear.
	[[self window] setToolbar:nil];
	[[self window] setToolbar:_toolbar];
	if (!_currentViewController)
		[self selectControllerAtIndex:0];
}

- (NSViewController<MASPreferencesViewController> *) currentViewController {
	return _currentViewController;
}

- (void) selectControllerAtIndex:(NSUInteger)index {
	if (index >= _viewControllers.count)
		return;

	NSViewController<MASPreferencesViewController> *controller = _viewControllers[index];
	[self selectControllerWithIdentifier:controller.viewIdentifier];
}

// The toolbar drops items it has no room for into an overflow menu, and there
// is no way to ask it how wide it would like to be, so widen the window until
// it shows them all.
- (void) _widenWindowUntilToolbarFits {
	NSWindow *window = [self window];
	NSUInteger wanted = [[_toolbar items] count];
	CGFloat limit = NSWidth([[window screen] visibleFrame]);

	while ([[_toolbar visibleItems] count] < wanted) {
		NSRect frame = [window frame];
		if (NSWidth(frame) + 40. > limit) break;
		frame.size.width += 40.;
		[window setFrame:frame display:NO];
	}

	_paneWidth = MAX(_paneWidth, NSWidth([window contentRectForFrameRect:[window frame]]));
}

- (void) selectControllerWithIdentifier:(NSString *)identifier {
	NSViewController<MASPreferencesViewController> *controller = nil;
	for (NSViewController<MASPreferencesViewController> *candidate in _viewControllers) {
		if ([candidate.viewIdentifier isEqualToString:identifier]) {
			controller = candidate;
			break;
		}
	}

	if (!controller)
		return;

	if (controller == _currentViewController)
		return;

	_currentViewController = controller;

	// Each pane is laid out at its own size in its nib, so the window takes
	// the pane's size rather than the pane being stretched to the window.
	NSView *view = controller.view;
	NSSize size = [view frame].size;
	// GNUstep's toolbar items are wider than Cocoa's, so a narrow pane pushes
	// the rest of the panes into the overflow menu.  Keep every pane at the
	// width of the widest one, and at least as wide as the toolbar needs, so
	// all of them stay reachable from the toolbar itself.
	if (_paneWidth == 0.) {
		for (NSViewController *candidate in _viewControllers)
			_paneWidth = MAX(_paneWidth, NSWidth([candidate.view frame]));
	}
	size.width = _paneWidth;
	// Grow or shrink downwards, keeping the title bar where the user put it.
	NSRect frame = [self.window frame];
	NSRect content = [self.window contentRectForFrameRect:frame];
	content.origin.y += NSHeight(content) - size.height;
	content.size = size;
	[self.window setFrame:[self.window frameRectForContentRect:content] display:YES];
	[view setFrameOrigin:NSZeroPoint];
	[view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[[self.window contentView] setSubviews:@[view]];

	[self _widenWindowUntilToolbarFits];

	[_toolbar setSelectedItemIdentifier:controller.viewIdentifier];

	NSString *label = controller.toolbarItemLabel ?: controller.viewIdentifier;
	[self.window setTitle:label];
}

#pragma mark - NSToolbarDelegate

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
	NSViewController<MASPreferencesViewController> *controller = nil;
	for (NSViewController<MASPreferencesViewController> *candidate in _viewControllers) {
		if ([candidate.viewIdentifier isEqualToString:itemIdentifier]) {
			controller = candidate;
			break;
		}
	}

	if (!controller)
		return nil;

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	[item setLabel:controller.toolbarItemLabel];
	[item setImage:controller.toolbarItemImage];
	[item setTarget:self];
	[item setAction:@selector(_toolbarItemClicked:)];
	return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:_viewControllers.count];
	for (NSViewController<MASPreferencesViewController> *controller in _viewControllers)
		[identifiers addObject:controller.viewIdentifier];
	return identifiers;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (void) _toolbarItemClicked:(NSToolbarItem *)item {
	[self selectControllerWithIdentifier:item.itemIdentifier];
}

#pragma mark - NSWindowDelegate

- (void) windowWillClose:(NSNotification *)notification {
	[self.window setToolbar:nil];
	[self setWindow:nil];
}

@end