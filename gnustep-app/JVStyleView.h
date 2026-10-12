/*
 * JVStyleView.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep native replacement for Colloquy's WebKit-based transcript view.
 *
 * The upstream JVStyleView rendered the chat transcript as HTML inside a
 * WebView, driven by XSLT stylesheets.  GNUstep has no WebKit, so this class
 * renders the transcript directly as attributed text in an NSTextView with
 * the same public interface the panels expect.
 */

#ifndef GS_JVSTYLEVIEW_H
#define GS_JVSTYLEVIEW_H

#import <Cocoa/Cocoa.h>

@class JVMarkedScroller;
@class JVChatTranscript;
@class JVChatMessage;
@class JVStyle;
@class JVEmoticonSet;
@class GSDOMRangeStub;
@class WebPreferences;
@class WebFrame;
@class WebScriptObject;

@protocol JVChatTranscriptElement;

extern NSString *JVStyleViewDidClearNotification;
extern NSString *JVStyleViewDidChangeStylesNotification;

@interface JVStyleView : NSView {
@private
	IBOutlet NSTextView *nextTextView;
	BOOL _forwarding;
	BOOL _switchingStyles;
	BOOL _ready;

	NSScrollView *_scrollView;
	NSTextView *_textView;
	NSTextStorage *_storage;

	JVChatTranscript *_transcript;
	JVStyle *_style;
	NSString *_styleVariant;
	NSMutableDictionary *_styleParameters;
	JVEmoticonSet *_emoticons;
	NSString *_bodyTemplate;
	NSUInteger _scrollbackLimit;
	NSUInteger _visibleMessageCount;
	BOOL _scrolledToBottom;
	BOOL _pendingScrollToBottom;
	WebFrame *_mainFrame;
	NSMutableDictionary *_messageRanges;
	NSMutableArray *_markLocations;
	NSMutableArray *_highlightedIdentifiers;
}

+ (void) emptyCache;

- (void) setTranscript:(JVChatTranscript *) transcript;
- (JVChatTranscript *) transcript;

- (void) setStyle:(JVStyle *) style;
- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant;
- (JVStyle *) style;

- (void) setStyleVariant:(NSString *) variant;
- (NSString *) styleVariant;

- (void) setBodyTemplate:(NSString *) bodyTemplate;
- (NSString *) bodyTemplate;

- (void) addBanner:(NSString *) name;

- (void) setStyleParameters:(NSDictionary *) parameters;
- (NSDictionary *) styleParameters;

- (void) setEmoticons:(JVEmoticonSet *) emoticons;
- (JVEmoticonSet *) emoticons;

- (void) setScrollbackLimit:(NSUInteger) limit;
- (NSUInteger) scrollbackLimit;

- (void) reloadCurrentStyle;
- (void) clear;
- (void) mark;

- (BOOL) appendChatMessage:(JVChatMessage *) message;
- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element;

- (void) highlightMessage:(JVChatMessage *) message;
- (void) clearHighlightForMessage:(JVChatMessage *) message;
- (void) clearAllMessageHighlights;

- (void) highlightString:(NSString *) string inMessage:(JVChatMessage *) message;
- (void) clearStringHighlightsForMessage:(JVChatMessage *) message;
- (void) clearAllStringHighlights;

- (void) markScrollbarForMessage:(JVChatMessage *) message;
- (void) markScrollbarForMessage:(JVChatMessage *) message usingMarkIdentifier:(NSString *) identifier andColor:(NSColor *) color;
- (void) markScrollbarForMessages:(NSArray *) messages;

- (void) clearScrollbarMarks;
- (void) clearScrollbarMarksWithIdentifier:(NSString *) identifier;

- (JVMarkedScroller *) verticalMarkedScroller;
- (IBAction) jumpToMark:(id) sender;
- (IBAction) jumpToPreviousHighlight:(id) sender;
- (IBAction) jumpToNextHighlight:(id) sender;
- (void) jumpToMessage:(JVChatMessage *) message;
- (void) scrollToBottom;
- (BOOL) scrolledNearBottom;

- (NSTextView *) nextTextView;
- (void) setNextTextView:(NSTextView *) textView;

// WebView delegate setter compatibility (no-ops; the native view has no
// delegates).
- (void) setUIDelegate:(id)delegate;
- (id) UIDelegate;
- (void) setPolicyDelegate:(id)delegate;
- (id) policyDelegate;
- (void) setFrameLoadDelegate:(id)delegate;
- (id) frameLoadDelegate;
- (void) setResourceLoadDelegate:(id)delegate;
- (id) resourceLoadDelegate;
- (void) setDownloadDelegate:(id)delegate;
- (id) downloadDelegate;
- (void) setHostWindow:(NSWindow *)window;
- (NSWindow *) hostWindow;

// WebView-style preferences accessor: JVDirectChatPanel reads the transcript
// font family/size from here, the Appearance preference pane writes it.
- (WebPreferences *) preferences;
- (void) setPreferencesIdentifier:(NSString *)identifier;

// WebView-style frame and script accessors the panels use; see JVStyleView.m.
- (WebFrame *) mainFrame;
- (WebScriptObject *) windowScriptObject;

// Message positions, used to mark away periods on the scroller.
- (NSUInteger) _visibleMessageCount;
- (NSUInteger) _locationOfElementAtIndex:(NSUInteger) index;

// Internal helpers
- (NSTextView *) _textView;

// Selected-text DOM compatibility: the panels call display.selectedDOMRange.text
// (a DOMRange in WebKit); expose the selection as a plain string.  The class is
// declared here so the .text dot-syntax compiles in the panels.
- (GSDOMRangeStub *) selectedDOMRange;
@end

@interface GSDOMRangeStub : NSObject {
@private
	NSString *_text;
}
@property (readonly, nonatomic) NSString *text;
- (instancetype) initWithString:(NSString *)string;
@end

#endif // GS_JVSTYLEVIEW_H