/*
 * JVStyleView.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep native transcript view.  Renders Colloquy chat messages as
 * attributed text in an NSTextView instead of the upstream WebKit HTML view.
 */

#import "JVStyleView.h"

#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"

NSString *JVStyleViewDidClearNotification = @"JVStyleViewDidClearNotification";
NSString *JVStyleViewDidChangeStylesNotification = @"JVStyleViewDidChangeStylesNotification";

// Minimal stand-in for WebKit's DOMRange: holds the selected text so the
// "search the web for the selection" menu action keeps working.
@implementation JVStyleView

+ (void) emptyCache { }

- (id) initWithFrame:(NSRect)frameRect {
	if (!(self = [super initWithFrame:frameRect]))
		return nil;

	_scrollbackLimit = 1000;
	_scrolledToBottom = YES;
	_pendingScrollToBottom = YES;
	_styleParameters = [[NSMutableDictionary alloc] initWithCapacity:5];

	_scrollView = [[NSScrollView alloc] initWithFrame:[self bounds]];
	[_scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[_scrollView setHasVerticalScroller:YES];
	[_scrollView setAutohidesScrollers:YES];
	[_scrollView setBorderType:NSNoBorder];

	_storage = [[NSTextStorage alloc] initWithString:@""];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
	[_storage addLayoutManager:layoutManager];
	NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize([self bounds].size.width, 1.0e7)];
	[container setWidthTracksTextView:YES];
	[layoutManager addTextContainer:container];

	_textView = [[NSTextView alloc] initWithFrame:[self bounds] textContainer:container];
	[_textView setMinSize:NSMakeSize(0.0, 0.0)];
	[_textView setMaxSize:NSMakeSize(1.0e7, 1.0e7)];
	[_textView setVerticallyResizable:YES];
	[_textView setHorizontallyResizable:NO];
	[_textView setAutoresizingMask:NSViewWidthSizable];
	[_textView setEditable:NO];
	[_textView setSelectable:YES];
	[_textView setRichText:YES];
	[_textView setUsesFontPanel:YES];
	[_textView setTextContainerInset:NSMakeSize(8.0, 8.0)];

	// Which part of the text a message was rendered into, so it can be
	// highlighted, searched and scrolled to later.  Keyed by the message
	// identifier because the transcript hands out its own message objects for
	// the same message the view rendered.
	_messageRanges = [[NSMutableDictionary alloc] init];
	_markLocations = [[NSMutableArray alloc] init];
	_highlightedIdentifiers = [[NSMutableArray alloc] init];

	[_scrollView setDocumentView:_textView];

	[self addSubview:_scrollView];
	[self setAutoresizesSubviews:YES];

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_textViewDidScroll:) name:NSScrollViewDidLiveScrollNotification object:_scrollView];
	[center addObserver:self selector:@selector(_textViewDidScroll:) name:NSScrollViewDidEndLiveScrollNotification object:_scrollView];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) awakeFromNib {
	// The nib instantiates this view with the scroll view/text view already
	// laid out; replace the placeholder content with our transcript views.
	if ([_scrollView superview] != self) {
		[_scrollView removeFromSuperview];
		[_scrollView setFrame:[self bounds]];
		[_scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[self addSubview:_scrollView];
	}

	[self _postDidChangeStyles];
}

- (void) setFrameSize:(NSSize)newSize {
	[super setFrameSize:newSize];
	[_scrollView setFrame:[self bounds]];
}

- (void) setTranscript:(JVChatTranscript *) transcript {
	_transcript = transcript;

	if (!_ready) {
		_ready = YES;
		[self _renderHistory];
	}
}

- (JVChatTranscript *) transcript { return _transcript; }

- (void) setStyle:(JVStyle *) style { [self setStyle:style withVariant:nil]; }

- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant {
	_style = style;
	_styleVariant = [variant copy];
	[self _postDidChangeStyles];
}

// Panels configure themselves for the style in response to this (the chat
// input font among other things), so it has to be posted here as well even
// though this view does not render the style's HTML.
- (void) _postDidChangeStyles {
	[[NSNotificationCenter defaultCenter] postNotificationName:JVStyleViewDidChangeStylesNotification object:self];
	[[NSNotificationCenter chatCenter] postNotificationName:JVStyleViewDidChangeStylesNotification object:self];
}

- (JVStyle *) style { return _style; }

- (void) setStyleVariant:(NSString *) variant { _styleVariant = [variant copy]; }
- (NSString *) styleVariant { return _styleVariant; }

- (void) setBodyTemplate:(NSString *) bodyTemplate { _bodyTemplate = [bodyTemplate copy]; }
- (NSString *) bodyTemplate { return _bodyTemplate; }

- (void) addBanner:(NSString *) name {
	if (!name.length)
		return;

	NSDictionary *userInfo = nil;

	if ([name isEqualToString:@"roomTopicBanner"] && _transcript) {
		// The topic is not part of the transcript; the room panel sets it
		// separately via setStyleParameters.  Show it if provided.
		NSString *topicText = _styleParameters[@"topic"] ?: @"";
		if (topicText.length) {
			NSMutableString *banner = [NSMutableString stringWithString:topicText];
			[banner appendString:@"\n"];
			[self _appendBannerText:banner];
		}
	} else {
		// Generic informational banner from the panel.
		NSAttributedString *text = [self _bannerAttributedStringForName:name userInfo:userInfo];
		[self _appendAttributedString:text];
	}
}

- (void) setStyleParameters:(NSDictionary *) parameters {
	_styleParameters = [parameters mutableCopy];
}

- (NSDictionary *) styleParameters { return [_styleParameters copy]; }

- (void) setEmoticons:(JVEmoticonSet *) emoticons { _emoticons = emoticons; }
- (JVEmoticonSet *) emoticons { return _emoticons; }

- (void) setScrollbackLimit:(NSUInteger) limit {
	_scrollbackLimit = limit;
	[self _enforceScrollbackLimit];
}
- (NSUInteger) scrollbackLimit { return _scrollbackLimit; }

- (void) reloadCurrentStyle { [self _renderHistory]; }

- (void) clear {
	[_storage deleteCharactersInRange:NSMakeRange(0, _storage.length)];
	[_messageRanges removeAllObjects];
	[_markLocations removeAllObjects];
	[_highlightedIdentifiers removeAllObjects];
	_visibleMessageCount = 0;
	[[NSNotificationCenter defaultCenter] postNotificationName:JVStyleViewDidClearNotification object:self];
}

- (void) mark {
	NSRange insertionPoint = NSMakeRange(_storage.length, 0);
	// Plain dashes: the box-drawing characters are missing from the fonts
	// GNUstep falls back to here and come out as question marks.
	NSString *markText = [NSString stringWithFormat:@"\n--- %@ ---\n\n",
		NSLocalizedString(@"New Messages", "transcript mark line")];
	NSAttributedString *mark = [[NSAttributedString alloc] initWithString:markText
		attributes:@{ NSFontAttributeName: [NSFont boldSystemFontOfSize:11.0],
			NSForegroundColorAttributeName: [NSColor grayColor] }];
	[_storage appendAttributedString:mark];
	[_markLocations addObject:@(insertionPoint.location)];
	[self scrollToBottom];
}

- (BOOL) appendChatMessage:(JVChatMessage *) message {
	if (!message)
		return NO;

	NSAttributedString *render = [self _renderMessage:message];
	NSUInteger start = _storage.length;
	[self _appendAttributedString:render];
	if ([message messageIdentifier].length)
		[_messageRanges setObject:[NSValue valueWithRange:NSMakeRange(start, _storage.length - start)] forKey:[message messageIdentifier]];
	_visibleMessageCount++;
	[self _enforceScrollbackLimit];
	return YES;
}

- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element {
	if ([element respondsToSelector:@selector(body)]) {
		NSAttributedString *body = [(JVChatMessage *)element body];
		if (body) {
			NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:@""];
			[line appendAttributedString:body];
			[line appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
			[self _appendAttributedString:line];
			_visibleMessageCount++;
			[self _enforceScrollbackLimit];
			return YES;
		}
	}

	return NO;
}

- (NSRange) _rangeOfMessage:(JVChatMessage *) message {
	NSString *identifier = [message messageIdentifier];
	NSValue *range = (identifier.length ? [_messageRanges objectForKey:identifier] : nil);
	if (!range)
		return NSMakeRange(NSNotFound, 0);

	NSRange result = [range rangeValue];
	if (NSMaxRange(result) > _storage.length)
		return NSMakeRange(NSNotFound, 0);
	return result;
}

- (void) _setHighlightColor:(NSColor *) color forRange:(NSRange) range {
	if (range.location == NSNotFound)
		return;

	[_storage beginEditing];
	if (color) [_storage addAttribute:NSBackgroundColorAttributeName value:color range:range];
	else [_storage removeAttribute:NSBackgroundColorAttributeName range:range];
	[_storage endEditing];
	[_textView setNeedsDisplay:YES];
}

- (void) highlightMessage:(JVChatMessage *) message {
	NSString *identifier = [message messageIdentifier];
	if (identifier.length && ![_highlightedIdentifiers containsObject:identifier])
		[_highlightedIdentifiers addObject:identifier];

	NSRange range = [self _rangeOfMessage:message];
	[self _setHighlightColor:[NSColor selectedTextBackgroundColor] forRange:range];
	if (range.location != NSNotFound)
		[_textView scrollRangeToVisible:range];
}

- (void) clearHighlightForMessage:(JVChatMessage *) message {
	NSString *identifier = [message messageIdentifier];
	if (identifier) [_highlightedIdentifiers removeObject:identifier];
	[self _setHighlightColor:nil forRange:[self _rangeOfMessage:message]];
}

- (void) clearAllMessageHighlights {
	[_highlightedIdentifiers removeAllObjects];
	[self _setHighlightColor:nil forRange:NSMakeRange(0, _storage.length)];
}

- (void) highlightString:(NSString *) string inMessage:(JVChatMessage *) message {
	NSRange range = [self _rangeOfMessage:message];
	if (!string.length || range.location == NSNotFound)
		return;

	NSRange search = range;
	while (search.length) {
		NSRange found = [_storage.string rangeOfString:string options:NSCaseInsensitiveSearch range:search];
		if (found.location == NSNotFound)
			break;
		[self _setHighlightColor:[NSColor yellowColor] forRange:found];
		search = NSMakeRange(NSMaxRange(found), NSMaxRange(range) - NSMaxRange(found));
	}
}

- (void) clearStringHighlightsForMessage:(JVChatMessage *) message {
	[self _setHighlightColor:nil forRange:[self _rangeOfMessage:message]];
}

- (void) clearAllStringHighlights { [self clearAllMessageHighlights]; }

- (void) markScrollbarForMessage:(JVChatMessage *) message { (void)message; }
- (void) markScrollbarForMessage:(JVChatMessage *) message usingMarkIdentifier:(NSString *) identifier andColor:(NSColor *) color { (void)message; (void)identifier; (void)color; }
- (void) markScrollbarForMessages:(NSArray *) messages { (void)messages; }

- (void) clearScrollbarMarks { }
- (void) clearScrollbarMarksWithIdentifier:(NSString *) identifier { (void)identifier; }

- (JVMarkedScroller *) verticalMarkedScroller { return nil; }
- (IBAction) jumpToMark:(id) sender {
	(void)sender;
	NSNumber *location = [_markLocations lastObject];
	if (!location)
		return;

	NSUInteger start = [location unsignedIntegerValue];
	if (start > _storage.length)
		return;
	[_textView scrollRangeToVisible:NSMakeRange(start, 0)];
}

// The highlighted messages in the order they were rendered, so stepping
// through them follows the transcript.
- (NSArray *) _highlightedRangesInOrder {
	NSMutableArray *ranges = [NSMutableArray array];

	for (NSString *identifier in _highlightedIdentifiers) {
		NSValue *range = [_messageRanges objectForKey:identifier];
		if (range) [ranges addObject:range];
	}
	[ranges sortUsingComparator:^NSComparisonResult (NSValue *left, NSValue *right) {
		NSUInteger l = [left rangeValue].location, r = [right rangeValue].location;
		if (l < r) return NSOrderedAscending;
		return (l > r ? NSOrderedDescending : NSOrderedSame);
	}];
	return ranges;
}

- (void) _jumpToHighlightAfter:(BOOL) forward {
	NSArray *ranges = [self _highlightedRangesInOrder];
	if (!ranges.count)
		return;

	// Where the view is scrolled to, as a character index into the transcript.
	NSLayoutManager *layout = [_textView layoutManager];
	NSRange visibleGlyphs = [layout glyphRangeForBoundingRect:[_textView visibleRect]
		inTextContainer:[_textView textContainer]];
	NSUInteger current = [layout characterRangeForGlyphRange:visibleGlyphs actualGlyphRange:NULL].location;
	NSValue *target = nil;

	for (NSValue *candidate in ranges) {
		NSUInteger location = [candidate rangeValue].location;
		if (forward && location > current) { target = candidate; break; }
		if (!forward && location < current) target = candidate;
	}
	if (!target) target = (forward ? [ranges firstObject] : [ranges lastObject]);
	[_textView scrollRangeToVisible:[target rangeValue]];
}

- (IBAction) jumpToPreviousHighlight:(id) sender { (void)sender; [self _jumpToHighlightAfter:NO]; }
- (IBAction) jumpToNextHighlight:(id) sender { (void)sender; [self _jumpToHighlightAfter:YES]; }
- (void) jumpToMessage:(JVChatMessage *) message {
	NSRange range = [self _rangeOfMessage:message];
	if (range.location != NSNotFound)
		[_textView scrollRangeToVisible:range];
}

- (void) scrollToBottom {
	if (!_textView)
		return;
	_pendingScrollToBottom = YES;
	[_textView scrollRangeToVisible:NSMakeRange(_storage.length, 0)];
	_scrolledToBottom = YES;
}

- (BOOL) scrolledNearBottom {
	return _scrolledToBottom;
}

- (NSTextView *) nextTextView { return nextTextView; }
- (void) setNextTextView:(NSTextView *) textView { nextTextView = textView; }

- (NSTextView *) _textView { return _textView; }

// ---- WebView delegate compatibility (no-ops) --------------------------------
- (void) setUIDelegate:(id)delegate { (void)delegate; }
- (id) UIDelegate { return nil; }
- (void) setPolicyDelegate:(id)delegate { (void)delegate; }
- (id) policyDelegate { return nil; }
- (void) setFrameLoadDelegate:(id)delegate { (void)delegate; }
- (id) frameLoadDelegate { return nil; }
- (void) setResourceLoadDelegate:(id)delegate { (void)delegate; }
- (id) resourceLoadDelegate { return nil; }
- (void) setDownloadDelegate:(id)delegate { (void)delegate; }
- (id) downloadDelegate { return nil; }
- (void) setHostWindow:(NSWindow *)window { (void)window; }
- (NSWindow *) hostWindow { return nil; }

// The panels read the transcript font from WebPreferences; expose defaults.
- (WebPreferences *) preferences {
	return [[WebPreferences alloc] init];
}

// WebKit kept one set of preferences per identifier; there is a single
// transcript font here, so the identifier has nothing to select.
- (void) setPreferencesIdentifier:(NSString *)identifier { (void)identifier; }

// The panels forward page-up/down and home/end to the main frame's view; hand
// out the scroll view so those keys scroll the transcript.
- (WebFrame *) mainFrame {
	if (!_mainFrame)
		_mainFrame = [[WebFrame alloc] initWithFrameView:_scrollView];
	return _mainFrame;
}

// The upstream transcript styles expose JavaScript hooks (changeTopic,
// toggleTopic) that the room panel calls through here.  This transcript
// renders attributed text and has no script engine, so there is nothing to
// call into; the topic is drawn by -addBanner: instead.
- (WebScriptObject *) windowScriptObject { return nil; }

#pragma mark - Message positions

- (NSUInteger) _visibleMessageCount { return _visibleMessageCount; }

// The vertical position, in the scroll view's coordinates, of the paragraph
// holding the given message.  JVDirectChatPanel marks away/back periods on the
// scroller with it.
- (NSUInteger) _locationOfElementAtIndex:(NSUInteger) index {
	if (!_textView || index >= _visibleMessageCount)
		return NSNotFound;

	NSString *text = [_storage string];
	NSUInteger location = 0;
	for (NSUInteger paragraph = 0; paragraph < index; paragraph++) {
		NSRange range = [text paragraphRangeForRange:NSMakeRange(location, 0)];
		if (!range.length || NSMaxRange(range) >= [text length])
			return NSNotFound;
		location = NSMaxRange(range);
	}

	NSLayoutManager *layoutManager = [_textView layoutManager];
	NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:NSMakeRange(location, 0) actualCharacterRange:NULL];
	NSRect rect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[_textView textContainer]];
	return (NSUInteger)NSMinY(rect);
}

// WebKit exposes the selection as a DOMRange object with a -text property;
// GNUstep has no DOM, so return a small object carrying the selected string.
- (GSDOMRangeStub *) selectedDOMRange {
	return [[GSDOMRangeStub alloc] initWithString:[_textView string]];
}

#pragma mark - Rendering

- (NSAttributedString *) _bannerAttributedStringForName:(NSString *)name userInfo:(NSDictionary *)userInfo {
	(void)userInfo;
	NSString *text = [NSString stringWithFormat:@"-- %@ --\n", name];
	return [[NSAttributedString alloc] initWithString:text
		attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:11.0],
			NSForegroundColorAttributeName: [NSColor grayColor] }];
}

- (void) _appendBannerText:(NSString *)text {
	NSAttributedString *banner = [[NSAttributedString alloc] initWithString:text
		attributes:@{ NSFontAttributeName: [NSFont boldSystemFontOfSize:12.0],
			NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.2 green:0.4 blue:0.8 alpha:1.0] }];
	[self _appendAttributedString:banner];
}

- (NSAttributedString *) _renderMessage:(JVChatMessage *)message {
	NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:@""];

	NSDate *date = [message date];
	if (date) {
		static NSDateFormatter *formatter = nil;
		if (!formatter) {
			formatter = [[NSDateFormatter alloc] init];
			[formatter setDateStyle:NSDateFormatterNoStyle];
			[formatter setTimeStyle:NSDateFormatterMediumStyle];
		}
		NSString *timeString = [formatter stringFromDate:date];
		[line appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@] ", timeString]
			attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:10.0],
				NSForegroundColorAttributeName: [NSColor grayColor] }]];
	}

	NSString *senderName = nil;
	if ([message respondsToSelector:@selector(senderNickname)] && [message senderNickname].length)
		senderName = [message senderNickname];
	else if ([message respondsToSelector:@selector(senderName)] && [message senderName].length)
		senderName = [message senderName];

	BOOL isAction = [message respondsToSelector:@selector(isAction)] && [message isAction];

	if (senderName.length && !isAction) {
		[line appendAttributedString:[[NSAttributedString alloc] initWithString:[senderName stringByAppendingString:@": "]
			attributes:@{ NSFontAttributeName: [NSFont boldSystemFontOfSize:12.0],
				NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.1 green:0.2 blue:0.6 alpha:1.0] }]];
	}

	NSAttributedString *body = [message respondsToSelector:@selector(body)] ? [message body] : nil;
	if (body) {
		if (isAction) {
			NSMutableAttributedString *action = [body mutableCopy];
			NSFont *italic = [[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:12.0] toHaveTrait:NSItalicFontMask];
			[action addAttributes:@{ NSFontAttributeName: italic } range:NSMakeRange(0, action.length)];
			[line appendAttributedString:action];
		} else {
			[line appendAttributedString:body];
		}
	} else if ([message respondsToSelector:@selector(bodyAsPlainText)] && [message bodyAsPlainText]) {
		NSString *plain = [message bodyAsPlainText];
		[line appendAttributedString:[[NSAttributedString alloc] initWithString:plain
			attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:12.0] }]];
	}

	[line appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];

	return line;
}

- (void) _appendAttributedString:(NSAttributedString *)attributed {
	if (!_textView)
		return;

	NSRange previous = NSMakeRange(_storage.length, 0);
	[_storage appendAttributedString:attributed];

	if (_pendingScrollToBottom || _scrolledToBottom) {
		[_textView scrollRangeToVisible:NSMakeRange(_storage.length, 0)];
	} else {
		(void)previous;
	}

	_pendingScrollToBottom = NO;
}

// Messages whose text was trimmed away have no range any more; the rest moved
// towards the start of the storage by the length that was removed.
- (void) _shiftMessageRangesBy:(NSUInteger) removed {
	NSMutableArray *marks = [NSMutableArray array];
	for (NSNumber *location in _markLocations) {
		if ([location unsignedIntegerValue] >= removed)
			[marks addObject:@([location unsignedIntegerValue] - removed)];
	}
	[_markLocations setArray:marks];

	for (NSString *identifier in [_messageRanges allKeys]) {
		NSRange range = [[_messageRanges objectForKey:identifier] rangeValue];
		if (range.location < removed) {
			[_messageRanges removeObjectForKey:identifier];
			continue;
		}
		range.location -= removed;
		[_messageRanges setObject:[NSValue valueWithRange:range] forKey:identifier];
	}
}

- (void) _enforceScrollbackLimit {
	if (_scrollbackLimit == 0 || _visibleMessageCount <= _scrollbackLimit)
		return;

	NSUInteger toRemove = _visibleMessageCount - _scrollbackLimit;
	// Approximate: remove the first toRemove paragraphs from the storage.
	NSUInteger count = 0;
	NSUInteger location = 0;
	NSUInteger length = _storage.length;
	NSRange deleteRange = NSMakeRange(0, 0);

	while (count < toRemove && location < length) {
		NSRange paragraph = [_storage.string paragraphRangeForRange:NSMakeRange(location, 0)];
		if (paragraph.length == 0)
			break;
		deleteRange.length += paragraph.length;
		location = paragraph.location + paragraph.length;
		count++;
	}

	if (deleteRange.length > 0) {
		_visibleMessageCount -= count;
		[_storage deleteCharactersInRange:deleteRange];
		[self _shiftMessageRangesBy:deleteRange.length];
		[self scrollToBottom];
	}
}

- (void) _renderHistory {
	if (!_transcript)
		return;

	[self clear];

	NSArray *messages = [_transcript messages];
	for (JVChatMessage *message in messages)
		[self appendChatMessage:message];

	[self scrollToBottom];
}

- (void) _textViewDidScroll:(NSNotification *)notification {
	NSRect visible = _textView.visibleRect;
	NSRect bounds = _textView.bounds;
	CGFloat visibleBottom = NSMaxY(visible);
	CGFloat maxY = NSMaxY(bounds);
	_scrolledToBottom = (visibleBottom >= (maxY - 8.0));
}

@end

@implementation GSDOMRangeStub
- (instancetype) initWithString:(NSString *)string {
	if( ( self = [super init] ) ) _text = [string copy];
	return self;
}
- (NSString *) text { return _text; }
@end