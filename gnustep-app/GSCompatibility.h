/*
 * GSCompatibility.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep portability header for the Colloquy (Old) Mac application.
 *
 * Shims Apple-only frameworks and APIs used by the Colloquy 2.x GUI onto
 * GNUstep equivalents:
 *
 *   - WebKit (WebView/WebFrame/DOM)   -> GSWebView rendering HTML via
 *                                        NSAttributedString in an NSTextView
 *   - Sparkle (SUUpdater)             -> inert stub
 *   - Growl (GrowlApplicationBridge)  -> inert stub
 *   - Security (SecKeychain)          -> errSecItemNotFound stubs
 *   - SecurityInterface               -> inert stub
 *   - AddressBook (ABPeoplePickerView) -> inert stub
 *   - MASPreferences                  -> minimal GNUstep implementation
 *
 * Include this header from every app source file (via the build's
 * ADDITIONAL_CPPFLAGS -include option) so the upstream sources need no
 * further edits for the Apple-only imports.
 */

#ifndef GSCOMPATIBILITY_H
#define GSCOMPATIBILITY_H

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

// ---- Apple annotation macros not provided by GNUstep ----------------------
#ifndef NS_REQUIRES_SUPER
#define NS_REQUIRES_SUPER __attribute__((objc_requires_super))
#endif
#ifndef NS_RETURNS_RETAINED
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#endif
#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif
#ifndef NS_UNAVAILABLE
#define NS_UNAVAILABLE
#endif

// ---- Feature-gating macros (normally from MVAvailability.h) ---------------
#ifndef ENABLE
#define ENABLE(CHAT_FEATURE) (defined(ENABLE_##CHAT_FEATURE) && ENABLE_##CHAT_FEATURE)
#endif
#ifndef USE
#define USE(CHAT_FEATURE) (defined(USE_##CHAT_FEATURE) && USE_##CHAT_FEATURE)
#endif

// ---- Colloquy build defines (normally from Basic.pch) ---------------------
#ifndef COLLOQUY_EXPORT
#define COLLOQUY_EXPORT __attribute__((__visibility__("default")))
#endif

// ---- Apple-only types used by the app --------------------------------------
#ifndef OSType
#define OSType uint32_t
#endif

// See the same override in CQCompatibility.h.
#undef TARGET_OS_IPHONE
#define TARGET_OS_IPHONE 0
#undef TARGET_OS_OSX
#define TARGET_OS_OSX 1
typedef uint32_t UInt32;
typedef uint16_t UInt16;

// NSScriptObjectSpecifier lives in NSScriptObjectSpecifiers.h on GNUstep,
// which only defines the plural class.  The app uses the singular Apple name
// as a property type; alias it.
#import <Foundation/NSScriptObjectSpecifiers.h>
@class NSScriptObjectSpecifier;

// Apple's scripting classes used by JVChatController / JVChatMessage.  GNUstep
// ships none of them; define minimal stubs so the objectSpecifier categories
// compile and no-op.
typedef NS_ENUM(NSUInteger, NSRelativePosition) {
	NSRelativeBefore = 1,
	NSRelativeAfter = 2,
	NSRelativeStart = 3,
	NSRelativeEnd = 4
};

@interface NSScriptObjectSpecifier : NSObject
- (NSScriptObjectSpecifier *) startSpecifier;
- (NSScriptObjectSpecifier *) endSpecifier;
- (NSScriptObjectSpecifier *) baseSpecifier;
- (NSRelativePosition) relativePosition;
@end

@interface NSUniqueIDSpecifier : NSScriptObjectSpecifier
- (id) initWithContainerClassDescription:(NSClassDescription *)classDescription containerSpecifier:(NSScriptObjectSpecifier *)container key:(NSString *)key uniqueID:(id)uniqueID;
@end

@interface NSIndexSpecifier : NSScriptObjectSpecifier
- (id) initWithContainerClassDescription:(NSClassDescription *)classDescription containerSpecifier:(NSScriptObjectSpecifier *)container key:(NSString *)key index:(NSInteger)index;
- (NSInteger) index;
@end

@interface NSRangeSpecifier : NSScriptObjectSpecifier
- (NSScriptObjectSpecifier *) startSpecifier;
- (NSScriptObjectSpecifier *) endSpecifier;
@end

@interface NSPropertySpecifier : NSScriptObjectSpecifier
- (id) initWithContainerClassDescription:(NSClassDescription *)classDescription containerSpecifier:(NSScriptObjectSpecifier *)container key:(NSString *)key;
@end

@interface NSRelativeSpecifier : NSScriptObjectSpecifier
- (NSScriptObjectSpecifier *) baseSpecifier;
- (NSRelativePosition) relativePosition;
@end

// NSScriptObjectSpecifier methods the app calls (key,
// objectsByEvaluatingSpecifier) come from the Apple scripting API.
@interface NSScriptObjectSpecifier (GSCompatibility)
- (NSString *) key;
- (id) objectsByEvaluatingSpecifier;
- (id) objectsByEvaluatingWithContainers:(id)containers;
- (NSScriptClassDescription *) keyClassDescription;
@end

// NSScrollView live-scroll notifications do not exist on GNUstep AppKit.
extern NSString * const NSScrollViewDidLiveScrollNotification;
extern NSString * const NSScrollViewDidEndLiveScrollNotification;

// New-style NSAlertStyle constants used by the app; GNUstep only has the old
// NS...AlertStyle names.
#ifndef NSAlertStyleInformational
#define NSAlertStyleInformational NSInformationalAlertStyle
#endif
#ifndef NSAlertStyleWarning
#define NSAlertStyleWarning NSWarningAlertStyle
#endif
#ifndef NSAlertStyleCritical
#define NSAlertStyleCritical NSCriticalAlertStyle
#endif

// NSLayoutManagerDelegate exists on macOS but not GNUstep AppKit; the console
// panel declares it and sets itself as the layout manager delegate.
@protocol NSLayoutManagerDelegate
@end

// io_registry_entry_t (MVApplicationController) - IOKit HID idle detection.
typedef uint32_t io_registry_entry_t;
typedef uint32_t io_object_t;
typedef uint32_t kern_return_t;
typedef uint32_t mach_port_t;
typedef io_object_t io_iterator_t;
#define MACH_PORT_NULL ((mach_port_t)0)
#define KERN_SUCCESS 0
#define KERN_FAILURE 5

// Minimal IOKit surface used by MVApplicationController for idle detection.
// GNUstep has no IOKit; the stubs report no HID device so the app never
// considers the machine idle.
void IOMasterPort(mach_port_t bootstrapPort, mach_port_t *masterPort);
io_iterator_t IOServiceMatching(const char *name);
kern_return_t IOServiceGetMatchingServices(mach_port_t masterPort, io_iterator_t matching, io_iterator_t *existing);
io_object_t IOIteratorNext(io_iterator_t iterator);
void IOObjectRelease(io_object_t object);

// AppleEvent constants used for URL events and open-document searches.
typedef uint32_t FourCharCode;
extern FourCharCode keyAESearchText;
extern FourCharCode kInternetEventClass;
extern FourCharCode kAEGetURL;

// fsetxattr/fgetxattr are macOS extended-attribute APIs (6 args) that GNUstep
// lacks; the transcript model/browser uses them to tag log files with
// metadata.  Stub them as no-ops so logging and browsing still work without
// the metadata.
int fsetxattr(int fd, const char *name, const void *value, size_t size, unsigned int position, int options);
ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, unsigned int position, int options);

// NSImageNameStatus* constants do not exist on GNUstep AppKit; map them onto
// NSImageNameCaution so the buddy list status dots fall back to a real image.
#define NSImageNameStatusNone NSImageNameCaution
#define NSImageNameStatusPartiallyAvailable NSImageNameCaution
#define NSImageNameStatusAvailable NSImageNameCaution
#define NSImageNameStatusUnavailable NSImageNameCaution

// The app is compiled without ARC (it predates it).  __weak/__strong are
// clang qualifier macros that cannot be redefined; the two upstream headers
// that use __weak ivars (JVChatEvent.h, JVChatRoomMember.h) are fixed
// in-tree.  __bridge casts only exist under ARC; under MRC they are plain
// casts.
#if !__has_feature(objc_arc)
#define __bridge
#endif

// Apple nullability qualifiers are not keywords in clang by default, so they
// can be neutralized as empty macros; GNUstep headers that use them under
// NS_ASSUME_NONNULL_BEGIN expand fine.
#ifndef __nullable
#define __nullable
#endif
#ifndef __nonnull
#define __nonnull
#endif
#ifndef __null_unspecified
#define __null_unspecified
#endif

// NSDraggingItem is a newer AppKit class GNUstep does not ship; AICustomTab-
// Dragging only passes the item to a block it never uses, so a forward
// declaration suffices.
@class NSDraggingItem;

// GNUstep ships NSTrackingArea but NSView still only has the older tracking
// rectangle API, and NSEvent has no -trackingArea.  Both are implemented in
// GSCompatibility.m on top of -addTrackingRect:owner:userData:assumeInside:,
// so the hover buttons in the activity window and the outline views work.
@interface NSEvent (GSCompatibility)
- (NSTrackingArea *) trackingArea;
@end

@interface NSView (GSCompatibilityTrackingAreas)
- (void) addTrackingArea:(NSTrackingArea *)trackingArea;
- (void) removeTrackingArea:(NSTrackingArea *)trackingArea;
- (NSArray *) trackingAreas;
@end

// NSWindow gained the sheet API in 10.9; GNUstep has -beginSheet:completionHandler:
// but ends sheets only through NSApplication.  Forward to it.
@interface NSWindow (GSCompatibilitySheets)
- (void) endSheet:(NSWindow *)sheet;
- (void) endSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode;
@end

// Bindings the xibs use that GNUstep's AppKit does not offer: NSView's
// "hidden" and NSTabView's "selectedIdentifier" (the room inspector remembers
// its last tab with it).  Exposed and implemented in GSCompatibility.m.
@interface NSTabView (GSCompatibilityBindings)
- (id) selectedIdentifier;
- (void) setSelectedIdentifier:(id)identifier;
@end

// NSApplication implements -dockTile but its header does not declare it.
@interface NSApplication (GSCompatibilityDockTile)
- (NSDockTile *) dockTile;
@end

// -setItemArray: (10.14) is used behind an @available check, which is always
// true off Darwin, so it has to exist.  Implemented as replace-all.
@interface NSMenu (GSCompatibility)
- (void) setItemArray:(NSArray *)items;
@end

// GNUstep has no accessibility layer.  The cell and view setters are no-ops;
// -accessibilityDescription answers the image name, which is the closest thing
// to the macOS description Colloquy sets in the asset catalogue.
@interface NSCell (GSCompatibilityAccessibility)
- (void) setAccessibilityValueDescription:(NSString *)description;
- (void) setAccessibilityLabel:(NSString *)label;
@end

@interface NSView (GSCompatibilityAccessibility)
- (void) setAccessibilityLabel:(NSString *)label;
@end

@interface NSImage (GSCompatibilityAccessibility)
- (NSString *) accessibilityDescription;
@end

// NSAttributedString block enumeration (10.6) is missing from GNUstep; the
// console and chat panels use it to walk link and colour runs.  Implemented
// over -attribute:atIndex:longestEffectiveRange:inRange: in GSCompatibility.m.
typedef NS_OPTIONS(NSUInteger, NSAttributedStringEnumerationOptions) {
	NSAttributedStringEnumerationReverse = (1UL << 1),
	NSAttributedStringEnumerationLongestEffectiveRangeNotRequired = (1UL << 20)
};

@interface NSAttributedString (GSCompatibilityEnumeration)
- (void) enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block;
@end

// -changeColor: is an informal protocol on macOS: MVColorPanel walks the
// responder chain looking for it.  The call is guarded by -respondsToSelector:,
// so this declaration only has to make the send compile.
@interface NSObject (GSCompatibilityColorProtocol)
- (void) changeColor:(id)sender;
@end

// GNUstep's NSDragging.h forward declares NSDraggingSession but ships no such
// class and never starts a session, so the session-based NSDraggingSource
// callbacks in AICustomTabDragging are dead code here.  The class exists only
// so those callbacks compile.
@interface NSDraggingSession : NSObject
- (void) enumerateDraggingItemsWithOptions:(NSInteger)options forView:(NSView *)view classes:(NSArray *)classes searchOptions:(NSDictionary *)searchOptions usingBlock:(void (^)(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop))block;
@end

// NSStringDrawingTruncatesLastVisibleLine is missing from GNUstep's string
// drawing options; CQGroupCell uses it to ellipsize the unread-count line.
#ifndef NSStringDrawingTruncatesLastVisibleLine
#define NSStringDrawingTruncatesLastVisibleLine ((NSStringDrawingOptions)0x20)
#endif

// NSFontPanelModeMask is the macOS typedef for the mode mask enum; GNUstep
// declares the enum constants but not the type, and its
// -validModesForFontPanel: returns unsigned int, so the alias has to match
// that or overriding the method changes its signature.
typedef unsigned int NSFontPanelModeMask;

// The two-argument scrollerWidthForControlSize:scrollerStyle: (macOS 10.7+)
// is absent from GNUstep; JVMarkedScroller sizes itself with it.
@interface NSScroller (GSCompatibility)
+ (CGFloat) scrollerWidthForControlSize:(NSControlSize)controlSize scrollerStyle:(NSScrollerStyle)style;
@end

// CoreGraphics shading used by JVSideOutlineView's custom row highlight.
// GNUstep has no CoreGraphics; the functions are no-ops so the highlight
// falls back to the normal selection drawing.
typedef void *CGFunctionRef;
typedef void *CGColorSpaceRef;
typedef void *CGShadingRef;
struct CGFunctionCallbacks {
	unsigned int version;
	void *evaluate;
	void *releaseInfo;
};
typedef struct CGFunctionCallbacks CGFunctionCallbacks;
CGFunctionRef CGFunctionCreate(void *info, size_t domainDimension, const CGFloat *domain, size_t rangeDimension, const CGFloat *range, const CGFunctionCallbacks *callbacks);
CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void);
CGPoint CGPointMake(CGFloat x, CGFloat y);
CGShadingRef CGShadingCreateAxial(CGColorSpaceRef space, CGPoint start, CGPoint end, CGFunctionRef function, bool extendStart, bool extendEnd);
void CGContextDrawShading(void *context, CGShadingRef shading);
void CGShadingRelease(CGShadingRef shading);
void CGColorSpaceRelease(CGColorSpaceRef space);
void CGFunctionRelease(CGFunctionRef function);

// NSCell's -copyWithZone: duplicates the cell's memory.  The macOS runtime then
// retains what the strong instance variables of ARC classes point to; the
// GNUstep runtime does not, so the copy refers to the original's objects
// without owning them.  An ARC cell subclass therefore clears each object
// instance variable of a fresh copy before assigning it, or the assignment
// and the copy's destruction release objects the original still uses.
static inline void GSForgetCopiedIvar(void *ivar) { memset(ivar, 0, sizeof(id)); }

// convertRectToBacking: (macOS 10.7+) is missing on GNUstep; MVMenuButton
// only uses it for arrow geometry, so return the rect unchanged.
@interface NSView (GSCompatibility)
- (NSRect) convertRectToBacking:(NSRect)rect;
@end

// NSDataDetector is a macOS Foundation class GNUstep does not ship; the
// attributed-string link auto-detection uses it to turn URLs into links.
// Implemented over NSRegularExpression in GSCompatibility.m.
@interface NSDataDetector : NSObject
+ (NSDataDetector *) dataDetectorWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error;
- (NSArray *) matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
@end

// NSURLSessionConfiguration properties that only exist on iOS/macOS background
// sessions; NSURLSessionAdditions sets them before creating the session.
@interface NSURLSessionConfiguration (GSCompatibility)
@property BOOL discretionary;
@property BOOL allowsCellularAccess;
@property BOOL sessionSendsLaunchEvents;
@property BOOL shouldUseExtendedBackgroundIdleMode;
@property NSInteger multipathServiceType;
@end

typedef NSInteger NSURLSessionMultipathServiceType;
enum {
	NSURLSessionMultipathServiceTypeHandover = 1
};

// NSOperationNotSupportedForKeyException exists on macOS but not GNUstep.
#ifndef NSOperationNotSupportedForKeyException
#define NSOperationNotSupportedForKeyException @"NSOperationNotSupportedForKeyException"
#endif

// ---- Mac-only framework headers (stubbed in gnustep-app/) ------------------
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <SecurityInterface/SFCertificateTrustPanel.h>
#import <AddressBook/ABPeoplePickerView.h>
#import <Sparkle/SUUpdater.h>
#import <Growl/GrowlApplicationBridge.h>
#import <MASPreferences/MASPreferences.h>

// ---- Cocoa scripting (AppleScript) -----------------------------------------
// GNUstep ships NSScriptCommand, NSScriptClassDescription, NSAppleEventManager
// and NSAppleEventDescriptor as empty placeholder classes, so none of the API
// the upstream scripting support uses exists.  Scripting is switched off in
// this port (ENABLE_SCRIPTING=0) and the AppleScript engine that would create
// and dispatch script commands does not exist either.
//
// The two entry points ordinary (non-scripting) code reaches are implemented
// in GSCompatibility.m and answer "no script is running":
//   +[NSScriptCommand currentCommand]          -> nil
//   -[NSObject objectSpecifier]                -> nil
// Everything below them is only ever reached from inside a dispatched script
// command, which cannot happen here, so it is declared but deliberately left
// unimplemented: should that code ever run it raises instead of silently
// pretending to have worked.

@interface NSScriptCommand (GSCompatibility)
+ (NSScriptCommand *) currentCommand;
@end

@interface NSScriptCommand (GSCompatibilityUnimplemented)
- (NSDictionary *) evaluatedArguments;
- (id) directParameter;
- (NSAppleEventDescriptor *) appleEvent;
- (NSScriptCommandDescription *) commandDescription;
- (void) setScriptErrorNumber:(NSInteger) number;
- (void) setScriptErrorString:(NSString *) string;
- (id) performDefaultImplementation;
@end

@interface NSScriptClassDescription (GSCompatibilityUnimplemented)
- (BOOL) supportsCommand:(NSScriptCommandDescription *) commandDescription;
- (SEL) selectorForCommand:(NSScriptCommandDescription *) commandDescription;
@end

@interface NSAppleEventDescriptor (GSCompatibilityUnimplemented)
- (NSAppleEventDescriptor *) attributeDescriptorForKeyword:(FourCharCode) keyword;
- (void) setAttributeDescriptor:(NSAppleEventDescriptor *) descriptor forKeyword:(FourCharCode) keyword;
- (NSAppleEventDescriptor *) descriptorForKeyword:(FourCharCode) keyword;
- (NSAppleEventDescriptor *) descriptorAtIndex:(NSInteger) index;
- (NSString *) stringValue;
@end

// Apple events never arrive on GNUstep.  The call sites guard these with
// +respondsToSelector:, so leaving them unimplemented is what makes the guards
// take the "no Apple events" branch.
@interface NSAppleEventManager (GSCompatibilityUnimplemented)
+ (NSAppleEventManager *) sharedAppleEventManager;
- (NSAppleEventDescriptor *) currentAppleEvent;
- (void) setEventHandler:(id) handler andSelector:(SEL) selector forEventClass:(FourCharCode) eventClass andEventID:(FourCharCode) eventID;
- (void) removeEventHandlerForEventClass:(FourCharCode) eventClass andEventID:(FourCharCode) eventID;
@end

// The AppleScript value-coercion registry.  Colloquy registers coercers from
// +initialize, which runs whether or not scripting is available, so the shared
// handler exists and accepts registrations; coercion itself is only reached
// from script commands.
@interface NSScriptCoercionHandler (GSCompatibility)
+ (NSScriptCoercionHandler *) sharedCoercionHandler;
- (void) registerCoercer:(Class) coercer selector:(SEL) selector toConvertFromClass:(Class) fromClass toClass:(Class) toClass;
- (id) coerceValue:(id) value toClass:(Class) toClass;
@end

// The +scriptTypedEncodingFromStringEncoding: helper in NSStringAdditions is
// compiled out with the rest of scripting; it is only read while answering a
// script command, so it is declared here and left unimplemented.  (The Chat
// Core scripting identifiers are declared further down, after ChatCore.h.)
@interface NSString (GSCompatibilityScriptingUnimplemented)
+ (OSType) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding;
@end

// -objectSpecifier is part of NSObject on macOS and returns nil for objects
// that are not scriptable, which is every object here.  Colloquy builds
// specifiers from it while handling ordinary notifications, so it has to
// answer rather than raise.
@interface NSObject (GSCompatibilityScripting)
- (NSScriptObjectSpecifier *) objectSpecifier;
@end

// The app's precompiled header on macOS pulled in MVUtilities.h (MVInline,
// MVSafeAdoptAssign etc.) and the ChatCore umbrella header for every file;
// inject them the same way here.
#import "MVUtilities.h"
#import <ChatCore/ChatCore.h>

// Chat Core compiles its scripting identifiers out along with the rest of
// scripting, and the connection scripting category in MVConnectionsController
// reads them.  That category only runs while answering a script command, which
// cannot happen here, so the accessor is declared and left unimplemented.
@interface MVChatConnection (GSCompatibilityScriptingUnimplemented)
- (NSNumber *) scriptUniqueIdentifier;
@end

// ---- NSApplication additions used by the app -------------------------------
@interface NSApplication (GSCompatibility)
- (BOOL) isFrozen; // macOS/iOS system freeze detection; always NO on GNUstep
- (BOOL) isTerminating;
@end

// ---- NSProcessInfo automatic/sudden termination (macOS-only) ---------------
// The app calls these on connect/disconnect and at launch. GNUstep's
// NSProcessInfo only implements the sudden-termination pair, so the
// automatic-termination selectors are provided as no-ops here (see
// GSCompatibility.m).
@interface NSProcessInfo (GSCompatibility)
- (void) setAutomaticTerminationSupportEnabled:(BOOL)flag;
- (void) disableAutomaticTermination:(NSString *)reason;
- (void) enableAutomaticTermination:(NSString *)reason;
@end

// ---- Installing the compatibility behaviour -------------------------------
// The method exchanges and binding registrations below must not run from
// +load: on a platform where GNUstep establishes argv through its private
// main() (GS_FAKE_MAIN, i.e. the BSDs), touching an AppKit class that early
// reaches NSUserDefaults and NSProcessInfo before argv exists, and
// NSProcessInfo then exits the process.  main() calls this instead, before
// any nib is loaded.
void GSCompatibilityInstall(void);

#endif // GSCOMPATIBILITY_H