/*
 * GSCompatibility.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Implementations of the GNUstep compatibility stubs declared in
 * GSCompatibility.h and the gnustep-app framework shims.
 */

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <SecurityInterface/SFCertificateTrustPanel.h>
#import <AddressBook/ABPeoplePickerView.h>
#import <Sparkle/SUUpdater.h>
#import <Growl/GrowlApplicationBridge.h>
#import <MASPreferences/MASPreferences.h>

#import <objc/runtime.h>

// ---- IOKit stubs (see GSCompatibility.h) ------------------------------------
void IOMasterPort(mach_port_t bootstrapPort, mach_port_t *masterPort) {
	(void)bootstrapPort;
	if (masterPort) *masterPort = MACH_PORT_NULL;
}

io_iterator_t IOServiceMatching(const char *name) { (void)name; return 0; }

kern_return_t IOServiceGetMatchingServices(mach_port_t masterPort, io_iterator_t matching, io_iterator_t *existing) {
	(void)masterPort; (void)matching;
	if (existing) *existing = 0;
	return KERN_FAILURE;
}

io_object_t IOIteratorNext(io_iterator_t iterator) { (void)iterator; return 0; }

void IOObjectRelease(io_object_t object) { (void)object; }

FourCharCode keyAESearchText = 'TEXT';
FourCharCode kInternetEventClass = 'GURL';
FourCharCode kAEGetURL = 'GURL';

// macOS extended-attribute stubs; see GSCompatibility.h.
int fsetxattr(int fd, const char *name, const void *value, size_t size, unsigned int position, int options) {
	(void)fd; (void)name; (void)value; (void)size; (void)position; (void)options;
	return 0;
}

ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, unsigned int position, int options) {
	(void)fd; (void)name; (void)value; (void)size; (void)position; (void)options;
	return -1;
}

// ---- Tracking areas ---------------------------------------------------------
// GNUstep has NSTrackingArea but no NSView support for it.  Map each tracking
// area onto a GNUstep tracking rectangle and remember the pairing, so that
// -trackingAreas answers what was added and mouseEntered:/mouseExited: can
// report the area the event came from.

static NSMapTable *GSTrackingAreasForView(NSView *view, BOOL create) {
	static NSMapTable *views = nil;
	if (!views) {
		if (!create) return nil;
		views = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaqueMemory
		                                  valueOptions:NSPointerFunctionsStrongMemory
		                                      capacity:8];
	}
	NSMapTable *areas = [views objectForKey:view];
	if (!areas && create) {
		// Tags are plain integers, so they are stored as opaque keys.
		areas = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaqueMemory
		                                  valueOptions:NSPointerFunctionsStrongMemory
		                                      capacity:8];
		[views setObject:areas forKey:view];
		[areas release];
	}
	return areas;
}

@implementation NSEvent (GSCompatibility)
- (NSTrackingArea *) trackingArea {
	// Tracking rectangles carry their NSTrackingArea as the user data.
	return (NSTrackingArea *)[self userData];
}
@end

@implementation NSView (GSCompatibilityTrackingAreas)
- (void) addTrackingArea:(NSTrackingArea *)trackingArea {
	if (!trackingArea) return;
	BOOL assumeInside = ([trackingArea options] & NSTrackingAssumeInside) != 0;
	NSTrackingRectTag tag = [self addTrackingRect:[trackingArea rect]
	                                        owner:[trackingArea owner]
	                                     userData:trackingArea
	                                 assumeInside:assumeInside];
	[GSTrackingAreasForView(self, YES) setObject:trackingArea forKey:(id)(intptr_t)tag];
}

- (void) removeTrackingArea:(NSTrackingArea *)trackingArea {
	NSMapTable *areas = GSTrackingAreasForView(self, NO);
	if (!areas) return;
	for (id key in [[areas keyEnumerator] allObjects]) {
		if ([areas objectForKey:key] != trackingArea) continue;
		[self removeTrackingRect:(NSTrackingRectTag)(intptr_t)key];
		[areas removeObjectForKey:key];
		break;
	}
}

- (NSArray *) trackingAreas {
	NSMapTable *areas = GSTrackingAreasForView(self, NO);
	if (!areas) return @[];
	return [[areas objectEnumerator] allObjects];
}
@end

@implementation NSDraggingSession
- (void) enumerateDraggingItemsWithOptions:(NSInteger)options forView:(NSView *)view classes:(NSArray *)classes searchOptions:(NSDictionary *)searchOptions usingBlock:(void (^)(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop))block {
	// A session is never created here, so it never carries dragging items.
	(void)options; (void)view; (void)classes; (void)searchOptions; (void)block;
}
@end

@implementation NSWindow (GSCompatibilitySheets)
- (void) endSheet:(NSWindow *)sheet {
	[NSApp endSheet:sheet];
}

- (void) endSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode {
	[NSApp endSheet:sheet returnCode:returnCode];
}
@end

// ---- NSViewController default nib -----------------------------------------
// Cocoa (10.10 and later) loads the nib named after the view controller's class
// when it was created without a nib name; the preference panes rely on that and
// are created with plain -init.  GNUstep leaves such a controller without a
// view, so supply the class-named nib when the bundle has one.

@implementation NSViewController (GSCompatibilityDefaultNib)
+ (void) load {
	Method original = class_getInstanceMethod(self, @selector(nibName));
	Method replacement = class_getInstanceMethod(self, @selector(_gs_nibName));
	method_exchangeImplementations(original, replacement);
}

- (NSString *) _gs_nibName {
	NSString *name = [self _gs_nibName];
	if (name)
		return name;
	for (Class class = [self class]; class && class != [NSViewController class]; class = [class superclass]) {
		NSString *candidate = NSStringFromClass(class);
		NSBundle *bundle = [self nibBundle] ?: [NSBundle bundleForClass:class];
		if ([bundle pathForResource:candidate ofType:@"nib"])
			return candidate;
	}
	return nil;
}
@end

// ---- Bindings missing from GNUstep's AppKit --------------------------------

@implementation NSView (GSCompatibilityBindings)
+ (void) load {
	// Nibs bind these; without them GNUstep logs "No binding exposed" and the
	// control silently ignores the user default it is meant to follow.
	[NSView exposeBinding:@"hidden"];
	[NSTabView exposeBinding:@"selectedIdentifier"];
}
@end

@implementation NSTabView (GSCompatibilityBindings)
+ (void) load {
	// GNUstep only writes a tab change back to the selectedIndex binding (from
	// -mouseDown:), so selection changes are routed through the method below.
	Method original = class_getInstanceMethod(self, @selector(selectTabViewItem:));
	Method replacement = class_getInstanceMethod(self, @selector(_gs_selectTabViewItem:));
	method_exchangeImplementations(original, replacement);
}

- (void) _gs_selectTabViewItem:(NSTabViewItem *)item {
	[self _gs_selectTabViewItem:item];

	NSDictionary *info = [self infoForBinding:@"selectedIdentifier"];
	if (!info) return;
	id observed = [info objectForKey:NSObservedObjectKey];
	NSString *keyPath = [info objectForKey:NSObservedKeyPathKey];
	id identifier = [[self selectedTabViewItem] identifier];
	// Writing an unchanged value would bounce straight back through KVO.
	if (identifier && ![[observed valueForKeyPath:keyPath] isEqual:identifier])
		[observed setValue:identifier forKeyPath:keyPath];
}

- (id) selectedIdentifier {
	return [[self selectedTabViewItem] identifier];
}

- (void) setSelectedIdentifier:(id)identifier {
	NSInteger index = identifier ? [self indexOfTabViewItemWithIdentifier:identifier] : NSNotFound;
	if (index != NSNotFound && [self tabViewItemAtIndex:index] != [self selectedTabViewItem])
		[self selectTabViewItemAtIndex:index];
}
@end

@implementation NSMenu (GSCompatibility)
- (void) setItemArray:(NSArray *)items {
	[self removeAllItems];
	for (NSMenuItem *item in items)
		[self addItem:item];
}
@end

@implementation NSCell (GSCompatibilityAccessibility)
- (void) setAccessibilityValueDescription:(NSString *)description { (void)description; }
- (void) setAccessibilityLabel:(NSString *)label { (void)label; }
@end

@implementation NSView (GSCompatibilityAccessibility)
- (void) setAccessibilityLabel:(NSString *)label { (void)label; }
@end

@implementation NSImage (GSCompatibilityAccessibility)
- (NSString *) accessibilityDescription { return [self name]; }
@end

@implementation NSAttributedString (GSCompatibilityEnumeration)
- (void) enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block {
	if (!block) return;
	BOOL reverse = (opts & NSAttributedStringEnumerationReverse) != 0;
	BOOL stop = NO;
	NSUInteger position = reverse ? NSMaxRange(enumerationRange) : enumerationRange.location;
	while (!stop && (reverse ? position > enumerationRange.location : position < NSMaxRange(enumerationRange))) {
		NSRange effective;
		NSUInteger index = reverse ? position - 1 : position;
		id value = [self attribute:attrName atIndex:index longestEffectiveRange:&effective inRange:enumerationRange];
		block(value, effective, &stop);
		position = reverse ? effective.location : NSMaxRange(effective);
	}
}
@end

@implementation NSScroller (GSCompatibility)
+ (CGFloat) scrollerWidthForControlSize:(NSControlSize)controlSize scrollerStyle:(NSScrollerStyle)style {
	(void)style;
	return [NSScroller scrollerWidthForControlSize:controlSize];
}
@end

// CoreGraphics shading stubs; see GSCompatibility.h.  All no-ops: the custom
// row highlight in JVSideOutlineView simply does not paint its gradient and
// the normal selection drawing is used instead.
CGFunctionRef CGFunctionCreate(void *info, size_t domainDimension, const CGFloat *domain, size_t rangeDimension, const CGFloat *range, const CGFunctionCallbacks *callbacks) {
	(void)info; (void)domainDimension; (void)domain; (void)rangeDimension; (void)range; (void)callbacks;
	return NULL;
}
CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void) { return NULL; }
CGPoint CGPointMake(CGFloat x, CGFloat y) { CGPoint p; p.x = x; p.y = y; return p; }
CGShadingRef CGShadingCreateAxial(CGColorSpaceRef space, CGPoint start, CGPoint end, CGFunctionRef function, bool extendStart, bool extendEnd) {
	(void)space; (void)start; (void)end; (void)function; (void)extendStart; (void)extendEnd;
	return NULL;
}
void CGContextDrawShading(void *context, CGShadingRef shading) { (void)context; (void)shading; }
void CGShadingRelease(CGShadingRef shading) { (void)shading; }
void CGColorSpaceRelease(CGColorSpaceRef space) { (void)space; }
void CGFunctionRelease(CGFunctionRef function) { (void)function; }

@implementation NSView (GSCompatibility)
- (NSRect) convertRectToBacking:(NSRect)rect { return rect; }
@end

// GNUstep's NSTextCheckingResult only knows regular-expression results: it has
// no +linkCheckingResultWithRange:URL: and no way to set a URL.  The detector
// below needs link results, so provide one that answers the range and URL it
// was created with.
@interface GSLinkCheckingResult : NSTextCheckingResult {
	NSRange _range;
	NSURL *_url;
}
- (instancetype) initWithRange:(NSRange)range URL:(NSURL *)url;
@end

@implementation GSLinkCheckingResult
- (instancetype) initWithRange:(NSRange)range URL:(NSURL *)url {
	if ((self = [super init])) {
		_range = range;
		_url = [url retain];
	}
	return self;
}

- (void) dealloc {
	[_url release];
	[super dealloc];
}

- (NSRange) range { return _range; }
- (NSURL *) URL { return _url; }
- (NSTextCheckingType) resultType { return NSTextCheckingTypeLink; }
- (NSUInteger) numberOfRanges { return 1; }
- (NSRange) rangeAtIndex:(NSUInteger)index { return index == 0 ? _range : NSMakeRange(NSNotFound, 0); }
@end

// NSDataDetector stand-in; see GSCompatibility.h.  Detects http(s), ftp and
// mailto links with a regular expression and wraps each match in an
// NSTextCheckingResult carrying a URL.
@implementation NSDataDetector {
	NSRegularExpression *_regex;
	NSTextCheckingType _types;
}

+ (NSDataDetector *) dataDetectorWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error {
	(void)error;
	if( ! ( checkingTypes & NSTextCheckingTypeLink ) ) return nil;
	NSDataDetector *detector = [[NSDataDetector alloc] init];
	detector->_types = checkingTypes;
	NSString *pattern = @"(?i)\\b((?:https?|ftp)://|www\\.)[^\\s<>{}\\[\\]\"']+|(?i)\\bmailto:[^\\s<>\"']+";
	detector->_regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:NULL];
	return detector;
}

- (NSArray *) matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range {
	NSMutableArray *results = [NSMutableArray array];
	for (NSTextCheckingResult *match in [_regex matchesInString:string options:options range:range]) {
		NSRange r = [match range];
		NSString *sub = [string substringWithRange:r];
		NSString *url = sub;
		if (![url hasPrefix:@"http://"] && ![url hasPrefix:@"https://"] && ![url hasPrefix:@"ftp://"] && ![url hasPrefix:@"mailto:"]) url = [@"http://" stringByAppendingString:url];
		NSURL *u = [NSURL URLWithString:url];
		if (u) [results addObject:[[[GSLinkCheckingResult alloc] initWithRange:r URL:u] autorelease]];
	}
	return results;
}

- (void) dealloc {
	[_regex release];
	[super dealloc];
}
@end

// NSURLSessionConfiguration background-session property stand-ins; these only
// matter on iOS (background app refresh) and are inert on the desktop.
@implementation NSURLSessionConfiguration (GSCompatibility)
- (BOOL) discretionary { return NO; }
- (void) setDiscretionary:(BOOL)flag { (void)flag; }
- (BOOL) allowsCellularAccess { return NO; }
- (void) setAllowsCellularAccess:(BOOL)flag { (void)flag; }
- (BOOL) sessionSendsLaunchEvents { return NO; }
- (void) setSessionSendsLaunchEvents:(BOOL)flag { (void)flag; }
- (BOOL) shouldUseExtendedBackgroundIdleMode { return NO; }
- (void) setShouldUseExtendedBackgroundIdleMode:(BOOL)flag { (void)flag; }
- (NSInteger) multipathServiceType { return 0; }
- (void) setMultipathServiceType:(NSInteger)type { (void)type; }
@end


// NSAEDescriptorTranslator stub; scripting is disabled so it never translates.
@interface NSAEDescriptorTranslator : NSObject
+ (id) _descriptorByTranslatingColor:(NSColor *)color ofType:(id)type inSuite:(id)suite;
@end

@implementation NSAEDescriptorTranslator
+ (id) _descriptorByTranslatingColor:(NSColor *)color ofType:(id)type inSuite:(id)suite {
	(void)color; (void)type; (void)suite;
	return nil;
}
@end

// GNUstep declares but does not define NSImageNameActionTemplate.  The value is
// Cocoa's, which names the image gnustep/images.py draws for the application.
NSString * const NSImageNameActionTemplate = @"NSActionTemplate";

// GNUstep AppKit lacks these scroll view notifications; they are only used to
// re-enter the run loop / update scroll indicators, which is a no-op here.
NSString * const NSScrollViewDidLiveScrollNotification = @"NSScrollViewDidLiveScroll";
NSString * const NSScrollViewDidEndLiveScrollNotification = @"NSScrollViewDidEndLiveScroll";

@implementation NSScriptObjectSpecifier
- (NSScriptObjectSpecifier *) startSpecifier { return nil; }
- (NSScriptObjectSpecifier *) endSpecifier { return nil; }
- (NSScriptObjectSpecifier *) baseSpecifier { return nil; }
- (NSRelativePosition) relativePosition { return NSRelativeStart; }
@end

@implementation NSUniqueIDSpecifier
- (id) initWithContainerClassDescription:(NSClassDescription *)classDescription containerSpecifier:(NSScriptObjectSpecifier *)container key:(NSString *)key uniqueID:(id)uniqueID {
	(void)classDescription; (void)container; (void)key; (void)uniqueID;
	return [super init];
}
@end

@implementation NSIndexSpecifier
- (id) initWithContainerClassDescription:(NSClassDescription *)classDescription containerSpecifier:(NSScriptObjectSpecifier *)container key:(NSString *)key index:(NSInteger)index {
	(void)classDescription; (void)container; (void)key; (void)index;
	return [super init];
}
- (NSInteger) index { return 0; }
@end

@implementation NSRangeSpecifier
- (NSScriptObjectSpecifier *) startSpecifier { return nil; }
- (NSScriptObjectSpecifier *) endSpecifier { return nil; }
@end

@implementation NSPropertySpecifier
- (id) initWithContainerClassDescription:(NSClassDescription *)classDescription containerSpecifier:(NSScriptObjectSpecifier *)container key:(NSString *)key {
	(void)classDescription; (void)container; (void)key;
	return [super init];
}
@end

@implementation NSRelativeSpecifier
- (NSScriptObjectSpecifier *) baseSpecifier { return nil; }
- (NSRelativePosition) relativePosition { return NSRelativeStart; }
@end

@implementation NSScriptObjectSpecifier (GSCompatibility)
- (NSString *) key { return @""; }
- (id) objectsByEvaluatingSpecifier { return nil; }
- (id) objectsByEvaluatingWithContainers:(id)containers { (void)containers; return nil; }
- (NSScriptClassDescription *) keyClassDescription { return nil; }
@end

// GNUstep declares but does not implement NSScriptCoercionHandler (the AppleScript
// value-coercion registry). Colloquy registers coercers and coerces values through
// it. On GNUstep scripting is unavailable, so provide a no-op shared handler.
@implementation NSScriptCoercionHandler (GSCompatibility)
+ (NSScriptCoercionHandler *) sharedCoercionHandler {
	static NSScriptCoercionHandler *handler = nil;
	if (!handler) handler = [[self alloc] init];
	return handler;
}
- (void) registerCoercer:(Class)coercer selector:(SEL)selector toConvertFromClass:(Class)fromClass toClass:(Class)toClass {
	(void)coercer; (void)selector; (void)fromClass; (void)toClass;
}
- (id) coerceValue:(id)value toClass:(Class)toClass {
	(void)toClass;
	return value;
}
@end

// Answers "no script command is running", which is always the case here.
@implementation NSScriptCommand (GSCompatibility)
+ (NSScriptCommand *) currentCommand { return nil; }
@end

// Nothing in this port is scriptable, so no object has a specifier.  macOS
// returns nil for the same reason on objects outside a scripting container.
@implementation NSObject (GSCompatibilityScripting)
- (NSScriptObjectSpecifier *) objectSpecifier { return nil; }
@end

// ---- NSApplication additions -------------------------------------------------

@implementation NSApplication (GSCompatibility)
- (BOOL) isFrozen { return NO; }
- (BOOL) isTerminating { return NO; }
@end

// ---- NSProcessInfo automatic/sudden termination (macOS-only) ---------------

@implementation NSProcessInfo (GSCompatibility)
- (void) setAutomaticTerminationSupportEnabled:(BOOL)flag { (void)flag; }
- (void) disableAutomaticTermination:(NSString *)reason { (void)reason; }
- (void) enableAutomaticTermination:(NSString *)reason { (void)reason; }
@end

// ---- Security keychain stubs ------------------------------------------------

OSStatus SecKeychainFindGenericPassword(const void *keychainOrArray,
	unsigned int serviceNameLength, const char *serviceName,
	unsigned int accountNameLength, const char *accountName,
	unsigned int *passwordLength, void **passwordData, SecKeychainItemRef *itemRef) {
	(void)keychainOrArray; (void)serviceNameLength; (void)serviceName;
	(void)accountNameLength; (void)accountName; (void)passwordLength;
	(void)passwordData; (void)itemRef;
	return errSecItemNotFound;
}

OSStatus SecKeychainFindInternetPassword(const void *keychainOrArray,
	unsigned int serverNameLength, const char *serverName,
	unsigned int securityDomainLength, const char *securityDomain,
	unsigned int accountNameLength, const char *accountName,
	unsigned int pathLength, const char *path,
	unsigned short port, SecProtocolType protocol, unsigned int authType,
	unsigned int *passwordLength, void **passwordData, SecKeychainItemRef *itemRef) {
	(void)keychainOrArray; (void)serverNameLength; (void)serverName;
	(void)securityDomainLength; (void)securityDomain; (void)accountNameLength;
	(void)accountName; (void)pathLength; (void)path; (void)port; (void)protocol;
	(void)authType; (void)passwordLength; (void)passwordData; (void)itemRef;
	return errSecItemNotFound;
}

OSStatus SecKeychainItemFreeContent(void *attrList, void *data) {
	(void)attrList; (void)data;
	return errSecSuccess;
}

OSStatus SecKeychainItemDelete(SecKeychainItemRef itemRef) {
	(void)itemRef;
	return errSecSuccess;
}

OSStatus SecKeychainAddGenericPassword(const void *keychain,
	unsigned int serviceNameLength, const char *serviceName,
	unsigned int accountNameLength, const char *accountName,
	unsigned int passwordLength, const void *passwordData,
	SecKeychainItemRef *itemRef) {
	(void)keychain; (void)serviceNameLength; (void)serviceName;
	(void)accountNameLength; (void)accountName; (void)passwordLength;
	(void)passwordData; (void)itemRef;
	return errSecItemNotFound;
}

OSStatus SecKeychainAddInternetPassword(const void *keychain,
	unsigned int serverNameLength, const char *serverName,
	unsigned int securityDomainLength, const char *securityDomain,
	unsigned int accountNameLength, const char *accountName,
	unsigned int pathLength, const char *path,
	unsigned short port, SecProtocolType protocol, unsigned int authType,
	unsigned int passwordLength, const void *passwordData,
	SecKeychainItemRef *itemRef) {
	(void)keychain; (void)serverNameLength; (void)serverName;
	(void)securityDomainLength; (void)securityDomain; (void)accountNameLength;
	(void)accountName; (void)pathLength; (void)path; (void)port; (void)protocol;
	(void)authType; (void)passwordLength; (void)passwordData; (void)itemRef;
	return errSecItemNotFound;
}

// ---- SecurityInterface stub ---------------------------------------------------

@implementation SFCertificateTrustPanel
+ (SFCertificateTrustPanel *) sharedCertificateTrustPanel { return [[self alloc] init]; }
- (void) setAlternateButtonTitle:(NSString *)title { (void)title; }
- (void) setDefaultButtonTitle:(NSString *)title { (void)title; }
- (NSInteger) runModalForTrust:(void *)trust showGroup:(BOOL)showGroup { (void)trust; (void)showGroup; return NSAlertFirstButtonReturn; }
- (void) beginSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo trust:(void *)trust showGroup:(BOOL)showGroup {
	(void)window; (void)trust; (void)showGroup; (void)contextInfo;
	if (delegate && didEndSelector && [delegate respondsToSelector:didEndSelector])
		objc_msgSend(delegate, didEndSelector, self, NSAlertFirstButtonReturn, contextInfo);
}
- (void) setInformativeText:(NSString *)text { (void)text; }
- (void) setMessageText:(NSString *)text { (void)text; }
@end

// ---- Address Book stub -------------------------------------------------------

@implementation ABPerson
+ (ABPerson *) person { return [[[self alloc] init] autorelease]; }
- (id) valueForProperty:(NSString *)property { (void)property; return nil; }
- (void) setValue:(id)value forProperty:(NSString *)property { (void)value; (void)property; }
- (NSString *) uniqueId { return [NSString stringWithFormat:@"gs-ab-person-%p", self]; }
- (NSString *) displayName { return @""; }
- (NSData *) imageData { return nil; }
- (NSInteger) beginLoadingImageDataForClient:(id <ABImageClient>)client { (void)client; return 0; }
@end

@implementation ABMultiValue
- (NSArray *) values { return @[]; }
- (NSUInteger) count { return 0; }
- (id) valueAtIndex:(NSUInteger)index { (void)index; return nil; }
- (id) primaryIdentifier { return nil; }
- (NSUInteger) indexForIdentifier:(id)identifier { (void)identifier; return NSNotFound; }
- (NSString *) labelAtIndex:(NSUInteger)index { (void)index; return nil; }
@end

@implementation ABAddressBook
// One shared instance, as on macOS: the buddy list holds on to the result and
// compares records by identity.
+ (ABAddressBook *) sharedAddressBook {
	static ABAddressBook *book = nil;
	if (!book) book = [[self alloc] init];
	return book;
}
- (ABPerson *) recordForUniqueId:(NSString *)uniqueId { (void)uniqueId; return nil; }
- (NSArray *) people { return @[]; }
- (ABPerson *) me { return nil; }
@end

@implementation ABPeoplePickerView
- (NSArray *) selectedRecords { return @[]; }
- (NSArray *) selectedValues { return @[]; }
- (void) setAllowsMultipleSelection:(BOOL)flag { (void)flag; }
- (BOOL) allowsMultipleSelection { return NO; }
- (void) setAllowsGroupSelection:(BOOL)flag { (void)flag; }
- (void) setTarget:(id)target { (void)target; }
- (void) setAction:(SEL)action { (void)action; }
- (void) setNameDoubleAction:(SEL)action { (void)action; }
- (void) addProperty:(NSString *)property { (void)property; }
@end

// ---- Sparkle stub ------------------------------------------------------------

@implementation SUUpdater
+ (SUUpdater *) sharedUpdater {
	static SUUpdater *updater = nil;
	if (!updater) updater = [[self alloc] init];
	return updater;
}
- (void) checkForUpdates:(id)sender { (void)sender; }
- (void) checkForUpdatesInBackground { }
- (void) setAutomaticallyChecksForUpdates:(BOOL)flag { (void)flag; }
- (BOOL) automaticallyChecksForUpdates { return NO; }
- (void) setUpdateCheckInterval:(NSTimeInterval)interval { (void)interval; }
- (NSTimeInterval) updateCheckInterval { return 0.; }
@end

// ---- Plain-text HTML import --------------------------------------------------
// Colloquy builds message/event bodies as HTML and converts them with
// +attributedStringWithXHTMLFragment:baseURL:defaultAttributes:. GNUstep's HTML
// importer is incomplete and crashes on common markup (e.g. <span class="...">),
// taking the whole app down on every incoming line. The goal here is plain text
// anyway, so strip the tags (and decode the usual entities) and return a plain
// attributed string. This is the single choke point for all such conversions.
@implementation NSAttributedString (GSCompatibility)
+ (NSAttributedString *) attributedStringWithXHTMLFragment:(NSString *)fragment baseURL:(NSURL *)baseURL defaultAttributes:(NSDictionary *)defaultAttributes {
	(void)baseURL;
	NSString *plain = nil;
	if( [fragment isKindOfClass:[NSAttributedString class]] )
		plain = [(NSAttributedString *)fragment string];
	else
		plain = fragment;

	if( ! [plain length] ) return [[self alloc] initWithString:@"" attributes:defaultAttributes];

	NSRange r;
	while( ( r = [plain rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch] ).location != NSNotFound )
		plain = [plain stringByReplacingCharactersInRange:r withString:@""];

	NSDictionary *entities = @{ @"&lt;":@"<", @"&gt;":@">", @"&amp;":@"&",
		@"&quot;":@"\"", @"&#39;":@"'", @"&apos;":@"'", @"&nbsp;":@" " };
	for( NSString *key in entities )
		plain = [plain stringByReplacingOccurrencesOfString:key withString:[entities objectForKey:key]];

	return [[self alloc] initWithString:plain attributes:defaultAttributes];
}
@end

// ---- Growl stub --------------------------------------------------------------

@implementation GrowlApplicationBridge
+ (void) setGrowlDelegate:(id <GrowlApplicationBridgeDelegate>)delegate { (void)delegate; }
+ (void) notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notificationName iconData:(NSData *)iconData priority:(int)priority isSticky:(BOOL)sticky clickContext:(id)context {
	(void)title; (void)description; (void)notificationName; (void)iconData;
	(void)priority; (void)sticky; (void)context;
}
+ (void) notifyWithDictionary:(NSDictionary *)dictionary { (void)dictionary; }
+ (BOOL) isGrowlRunning { return NO; }
@end