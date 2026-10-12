/*
 * WebKit.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep shim for the subset of WebKit used by Colloquy 2.x.
 *
 * Colloquy renders its chat transcript in a WebView.  GNUstep has no WebKit,
 * so this shim provides a WebView-compatible class (GSWebView) that renders
 * HTML into an NSAttributedString backed by an NSTextView.  The DOM types are
 * declared so the upstream delegate methods compile; the native transcript
 * (JVStyleView) is replaced by a GNUstep implementation in gnustep-app and
 * never uses them at runtime.
 */

#ifndef GS_WEBKIT_H
#define GS_WEBKIT_H

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

// ---- DOM type declarations (inert; the native transcript does not use DOM) -
@class DOMNode;
@class DOMDocument;
@class DOMElement;
@class DOMHTMLElement;
@class DOMHTMLDocument;
@class DOMNodeList;

// ---- WebScriptObject -------------------------------------------------------
@interface WebScriptObject : NSObject
- (void *) JSObject;
// Colloquy calls into the transcript's JavaScript through this; the native
// transcript has no script engine, so it answers nil (see WebView.m).
- (id) callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments;
@end

// ---- WebFrame -----------------------------------------------------------------
@class WebView;
@class NSURLRequest;
@class WebDataSource;

@interface WebFrame : NSObject
{
@private
	NSView *_frameView;
}
// The native transcript hands out a frame whose view is its scroll view, so
// that key events the panels forward to the frame actually scroll it.
- (instancetype) initWithFrameView:(NSView *)frameView;
- (WebView *) webView;
- (WebFrame *) parentFrame;
- (NSArray *) childFrames;
- (WebDataSource *) dataSource;
- (WebDataSource *) provisionalDataSource;
- (WebFrame *) findFrameNamed:(NSString *)name;
- (void) loadRequest:(NSURLRequest *)request;
- (void) loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void) reload;
- (void) stopLoading;
- (DOMDocument *) DOMDocument;
- (id) frameElement;
- (id) frameView;
@end

// ---- WebDataSource -----------------------------------------------------------
@class WebResource;

@interface WebDataSource : NSObject
- (WebFrame *) webFrame;
- (NSURLRequest *) request;
- (NSURL *) responseURL;
- (NSString *) pageTitle;
- (NSData *) data;
- (NSString *) textEncodingName;
@end

// ---- Delegate protocols (all optional; never invoked by the shim) ---------
@protocol WebPolicyDecisionListener <NSObject>
- (void) use;
- (void) ignore;
- (void) download;
@end

@protocol WebFrameLoadDelegate <NSObject>
@end

@protocol WebPolicyDelegate <NSObject>
@optional
- (void) webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener;
@end

@protocol WebResourceLoadDelegate <NSObject>
@end

@protocol WebUIDelegate <NSObject>
@optional
- (NSArray *) webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
@end

@protocol WebDocumentText
- (NSString *) string;
- (NSString *) selectedString;
@end

// ---- WebView -------------------------------------------------------------------
@protocol WebFrameLoadDelegate;
@protocol WebPolicyDelegate;
@protocol WebUIDelegate;
@protocol WebResourceLoadDelegate;

// ---- WebDownload (CQActivityWindowController direct downloads) -----------------
// WebKit's WebDownload is an NSURLDownload subclass that adds the
// authentication sheet.  GNUstep has NSURLDownload with the same delegate
// protocol, so the download itself works; only the sheet is missing.
#import <Foundation/NSURLDownload.h>

@interface WebDownload : NSURLDownload
@end

@interface WebView : NSView
{
@private
	NSView *_containerView; // hosts the rendered document view
	NSView *_documentView;  // NSTextView showing the loaded HTML
	NSString *_htmlString;
	NSURL *_baseURL;
	id _frameLoadDelegate;
	id _policyDelegate;
	id _UIDelegate;
	id _resourceLoadDelegate;
	BOOL _drawsBackground;
	BOOL _maintainsBackForwardList;
	NSString *_applicationNameForUserAgent;
	WebFrame *_mainFrame;
	NSString *_groupName;
}

- (void) _loadString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void) _renderHTML;

- (id) initWithFrame:(NSRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName;
- (WebFrame *) mainFrame;
- (WebFrame *) selectedFrame;
- (WebFrame *) focusedFrame;

- (void) setFrameLoadDelegate:(id <WebFrameLoadDelegate>)delegate;
- (id <WebFrameLoadDelegate>) frameLoadDelegate;
- (void) setPolicyDelegate:(id <WebPolicyDelegate>)delegate;
- (id <WebPolicyDelegate>) policyDelegate;
- (void) setUIDelegate:(id <WebUIDelegate>)delegate;
- (id <WebUIDelegate>) UIDelegate;
- (void) setResourceLoadDelegate:(id <WebResourceLoadDelegate>)delegate;
- (id <WebResourceLoadDelegate>) resourceLoadDelegate;

- (void) setDrawsBackground:(BOOL)flag;
- (BOOL) drawsBackground;
- (void) setMaintainsBackForwardList:(BOOL)flag;
- (BOOL) maintainsBackForwardList;
- (void) setApplicationNameForUserAgent:(NSString *)name;
- (NSString *) applicationNameForUserAgent;
- (void) setGroupName:(NSString *)name;
- (NSString *) groupName;

- (void) reload:(id)sender;
- (void) reloadFromOrigin:(id)sender;
- (void) stopLoading:(id)sender;
- (void) takeStringURLFrom:(id)sender;

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (WebScriptObject *) windowScriptObject;

- (void) close;
- (void) setHostWindow:(NSWindow *)window;
- (NSWindow *) hostWindow;

- (BOOL) canGoBack;
- (BOOL) canGoForward;
- (void) goBack:(id)sender;
- (void) goForward:(id)sender;

@end

// ---- WebKit constants used by the app ----------------------------------------
extern NSString * const WebElementFrameKey;
extern NSString * const WebElementImageKey;
extern NSString * const WebElementDOMNodeKey;
extern NSString * const WebElementLinkURLKey;
extern NSString * const WebElementImageURLKey;
extern NSString * const WebElementIsSelectedKey;
extern NSString * const WebActionOriginalURLKey;
extern NSString * const WebActionModifierFlagsKey;

// WebMenuItemTag* constants from WebUIDelegate.h, used in menu-tag switches.
typedef enum {
	WebMenuItemTagOpenLinkInNewWindow = 1,
	WebMenuItemTagOpenImageInNewWindow = 2,
	WebMenuItemTagOpenFrameInNewWindow = 3,
	WebMenuItemTagGoBack = 4,
	WebMenuItemTagGoForward = 5,
	WebMenuItemTagStop = 6,
	WebMenuItemTagReload = 7,
	WebMenuItemTagCopy = 8,
	WebMenuItemTagDownloadLinkToDisk = 10,
	WebMenuItemTagDownloadImageToDisk = 11,
	WebMenuItemTagSearchWeb = 12
} WebMenuItemTag;

// ---- WebPreferences (JVDirectChatPanel reads the transcript font from it) -----
// The transcript view reads its font from here, and the Appearance preference
// pane writes it, so the accessors are backed by the user defaults that
// JVStyleView renders with.  The remaining WebKit knobs have no equivalent in
// a plain text view and are accepted without effect.
@interface WebPreferences : NSObject
- (NSString *) standardFontFamily;
- (void) setStandardFontFamily:(NSString *)family;
- (NSInteger) defaultFontSize;
- (void) setDefaultFontSize:(NSInteger)size;
- (NSInteger) minimumFontSize;
- (void) setMinimumFontSize:(NSInteger)size;
- (void) setFixedFontFamily:(NSString *)family;
- (void) setSerifFontFamily:(NSString *)family;
- (void) setSansSerifFontFamily:(NSString *)family;
- (void) setUserStyleSheetEnabled:(BOOL)enabled;
- (void) setAutosaves:(BOOL)autosaves;
@end

// The defaults keys the transcript font is stored under; JVStyleView renders
// with them and WebPreferences reads and writes them.
extern NSString * const JVStyleStandardFontFamilyKey;
extern NSString * const JVStyleDefaultFontSizeKey;
extern NSString * const JVStyleMinimumFontSizeKey;

// ---- Frame-load delegate notifications ----------------------------------------
extern NSString * const WebViewProgressFinishedNotification;
extern NSString * const WebViewDidFinishLoadNotification;
extern NSString * const WebViewDidStartLoadNotification;
extern NSString * const WebViewProgressEstimateChangedNotification;

#endif // GS_WEBKIT_H