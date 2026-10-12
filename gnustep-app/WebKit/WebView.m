/*
 * WebView.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep implementation of the WebKit WebView shim.  Renders HTML into an
 * NSAttributedString hosted in an NSTextView.  Colloquy's chat transcript is
 * replaced by a native text view (JVStyleView in gnustep-app), so this class
 * is used only by the style preview and as a compile-time stand-in.
 */

#import <WebKit/WebKit.h>

NSString * const WebElementFrameKey = @"WebElementFrameKey";
NSString * const WebElementImageKey = @"WebElementImageKey";
NSString * const WebElementDOMNodeKey = @"WebElementDOMNodeKey";
NSString * const WebElementLinkURLKey = @"WebElementLinkURL";
NSString * const WebElementImageURLKey = @"WebElementImageURL";
NSString * const WebElementIsSelectedKey = @"WebElementIsSelected";
NSString * const WebActionOriginalURLKey = @"WebActionOriginalURL";
NSString * const WebActionModifierFlagsKey = @"WebActionModifierFlags";

NSString * const WebViewProgressFinishedNotification = @"WebViewProgressFinishedNotification";
NSString * const WebViewDidFinishLoadNotification = @"WebViewDidFinishLoadNotification";
NSString * const WebViewDidStartLoadNotification = @"WebViewDidStartLoadNotification";
NSString * const WebViewProgressEstimateChangedNotification = @"WebViewProgressEstimateChangedNotification";

@implementation WebScriptObject
- (void *) JSObject { return NULL; }
// The native transcript renders attributed text rather than a document with a
// script engine, so there is nothing to call into.
- (id) callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments {
	(void)name; (void)arguments;
	return nil;
}
@end

@implementation WebFrame
- (instancetype) initWithFrameView:(NSView *)frameView {
	if ((self = [super init]))
		_frameView = [frameView retain];
	return self;
}

- (void) dealloc {
	[_frameView release];
	[super dealloc];
}

- (WebView *) webView {
	return (WebView *)nil; // the frame's view; not tracked by the shim
}
- (WebFrame *) parentFrame { return nil; }
- (NSArray *) childFrames { return @[]; }
- (WebDataSource *) dataSource { return nil; }
- (WebDataSource *) provisionalDataSource { return nil; }
- (WebFrame *) findFrameNamed:(NSString *)name { (void)name; return self; }
- (void) loadRequest:(NSURLRequest *)request {
	WebView *view = [self webView];
	if (request && [view respondsToSelector:@selector(_loadString:baseURL:)])
		[view performSelector:@selector(_loadString:baseURL:) withObject:[request URL] withObject:nil];
}
- (void) loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
	WebView *view = [self webView];
	if (view && [view respondsToSelector:@selector(_loadString:baseURL:)])
		[view performSelector:@selector(_loadString:baseURL:) withObject:string withObject:baseURL];
}
- (void) reload { [[self webView] reload:nil]; }
- (void) stopLoading {}
- (DOMDocument *) DOMDocument { return nil; }
- (id) frameElement { return nil; }
- (id) frameView { return _frameView; }
@end

@implementation WebDataSource
- (WebFrame *) webFrame { return nil; }
- (NSURLRequest *) request { return nil; }
- (NSURL *) responseURL { return nil; }
- (NSString *) pageTitle { return nil; }
- (NSData *) data { return nil; }
- (NSString *) textEncodingName { return nil; }
@end

@implementation WebView
- (id) initWithFrame:(NSRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	_groupName = [groupName copy];
	_drawsBackground = YES;
	_maintainsBackForwardList = YES;
	_mainFrame = [[WebFrame alloc] init];

	return self;
}

- (WebFrame *) mainFrame { return _mainFrame; }
- (WebFrame *) selectedFrame { return _mainFrame; }
- (WebFrame *) focusedFrame { return _mainFrame; }

- (void) setFrameLoadDelegate:(id <WebFrameLoadDelegate>)delegate { _frameLoadDelegate = delegate; }
- (id <WebFrameLoadDelegate>) frameLoadDelegate { return _frameLoadDelegate; }
- (void) setPolicyDelegate:(id <WebPolicyDelegate>)delegate { _policyDelegate = delegate; }
- (id <WebPolicyDelegate>) policyDelegate { return _policyDelegate; }
- (void) setUIDelegate:(id <WebUIDelegate>)delegate { _UIDelegate = delegate; }
- (id <WebUIDelegate>) UIDelegate { return _UIDelegate; }
- (void) setResourceLoadDelegate:(id <WebResourceLoadDelegate>)delegate { _resourceLoadDelegate = delegate; }
- (id <WebResourceLoadDelegate>) resourceLoadDelegate { return _resourceLoadDelegate; }

- (void) setDrawsBackground:(BOOL)flag { _drawsBackground = flag; }
- (BOOL) drawsBackground { return _drawsBackground; }
- (void) setMaintainsBackForwardList:(BOOL)flag { _maintainsBackForwardList = flag; }
- (BOOL) maintainsBackForwardList { return _maintainsBackForwardList; }
- (void) setApplicationNameForUserAgent:(NSString *)name { _applicationNameForUserAgent = [name copy]; }
- (NSString *) applicationNameForUserAgent { return _applicationNameForUserAgent; }
- (void) setGroupName:(NSString *)name { _groupName = [name copy]; }
- (NSString *) groupName { return _groupName; }

- (void) _loadString:(NSString *)string baseURL:(NSURL *)baseURL {
	_htmlString = [string copy];
	_baseURL = baseURL;

	[self _renderHTML];
}

- (void) _renderHTML {
	if (!_documentView) {
		NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[self bounds]];
		[scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[scrollView setHasVerticalScroller:YES];
		[scrollView setHasHorizontalScroller:YES];
		[scrollView setAutohidesScrollers:YES];
		[scrollView setBorderType:NSNoBorder];

		NSTextView *textView = [[NSTextView alloc] initWithFrame:[scrollView contentView].bounds];
		[textView setMinSize:NSMakeSize(0.0, 0.0)];
		[textView setMaxSize:NSMakeSize(1.0e7, 1.0e7)];
		[textView setVerticallyResizable:YES];
		[textView setHorizontallyResizable:YES];
		[textView setAutoresizingMask:NSViewWidthSizable];
		[textView setEditable:NO];
		[textView setSelectable:YES];
		[textView setDrawsBackground:_drawsBackground];
		[[textView textContainer] setWidthTracksTextView:YES];
		[[textView textContainer] setContainerSize:NSMakeSize(1.0e7, 1.0e7)];

		[scrollView setDocumentView:textView];
		[self addSubview:scrollView];
		_documentView = scrollView;
		_containerView = scrollView;
	}

	NSData *htmlData = [_htmlString dataUsingEncoding:NSUTF8StringEncoding];
	NSAttributedString *attributed = [[NSAttributedString alloc] initWithHTML:htmlData baseURL:_baseURL documentAttributes:NULL];
	if (!attributed)
		attributed = [[NSAttributedString alloc] initWithString:_htmlString ?: @""];

	NSScrollView *scrollView = (NSScrollView *)_containerView;
	NSTextView *textView = (NSTextView *)[scrollView documentView];
	[[textView textStorage] setAttributedString:attributed];
	[textView scrollRangeToVisible:NSMakeRange(0, 0)];
}

- (void) reload:(id)sender { (void)sender; [self _renderHTML]; }
- (void) reloadFromOrigin:(id)sender { (void)sender; [self _renderHTML]; }
- (void) stopLoading:(id)sender { (void)sender; }
- (void) takeStringURLFrom:(id)sender { (void)sender; }

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *)script { (void)script; return @""; }
- (WebScriptObject *) windowScriptObject { return nil; }

- (void) close {
	[_documentView removeFromSuperview];
	_documentView = nil;
	_containerView = nil;
}

- (void) setHostWindow:(NSWindow *)window { (void)window; }
- (NSWindow *) hostWindow { return nil; }

- (BOOL) canGoBack { return NO; }
- (BOOL) canGoForward { return NO; }
- (void) goBack:(id)sender { (void)sender; }
- (void) goForward:(id)sender { (void)sender; }
@end
// ---- WebDownload ------------------------------------------------------------
// Everything WebDownload does beyond NSURLDownload is the authentication sheet,
// which GNUstep has no equivalent for; the download itself is inherited.
@implementation WebDownload
@end

// ---- WebPreferences -----------------------------------------------------------
// The transcript font lives in the user defaults: JVStyleView renders with it,
// JVDirectChatPanel sizes the input field from it and the Appearance preference
// pane changes it through this object.

NSString * const JVStyleStandardFontFamilyKey = @"JVStyleStandardFontFamily";
NSString * const JVStyleDefaultFontSizeKey = @"JVStyleDefaultFontSize";
NSString * const JVStyleMinimumFontSizeKey = @"JVStyleMinimumFontSize";

@implementation WebPreferences
- (NSString *) standardFontFamily {
	return [[NSUserDefaults standardUserDefaults] stringForKey:JVStyleStandardFontFamilyKey] ?: [NSFont systemFontOfSize:12.0].familyName;
}

- (void) setStandardFontFamily:(NSString *)family {
	[[NSUserDefaults standardUserDefaults] setObject:family forKey:JVStyleStandardFontFamilyKey];
}

- (NSInteger) defaultFontSize {
	NSNumber *size = [[NSUserDefaults standardUserDefaults] objectForKey:JVStyleDefaultFontSizeKey];
	return size ? [size integerValue] : 12;
}

- (void) setDefaultFontSize:(NSInteger)size {
	[[NSUserDefaults standardUserDefaults] setInteger:size forKey:JVStyleDefaultFontSizeKey];
}

- (NSInteger) minimumFontSize {
	NSNumber *size = [[NSUserDefaults standardUserDefaults] objectForKey:JVStyleMinimumFontSizeKey];
	return size ? [size integerValue] : 9;
}

- (void) setMinimumFontSize:(NSInteger)size {
	[[NSUserDefaults standardUserDefaults] setInteger:size forKey:JVStyleMinimumFontSizeKey];
}

// A plain text view has a single font, so the per-family WebKit settings and
// the WebKit-only switches below have nothing to apply to.
- (void) setFixedFontFamily:(NSString *)family { (void)family; }
- (void) setSerifFontFamily:(NSString *)family { (void)family; }
- (void) setSansSerifFontFamily:(NSString *)family { (void)family; }
- (void) setUserStyleSheetEnabled:(BOOL)enabled { (void)enabled; }
- (void) setAutosaves:(BOOL)autosaves { (void)autosaves; }
@end
