/*
 * SearchKit.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep shim for the subset of SearchKit (Spotlight) used by Colloquy 2.x.
 *
 * Colloquy's transcript browser indexes transcripts with SearchKit so the
 * search field can rank matches.  GNUstep has no SearchKit, so these types and
 * functions are declared for compilation and stubbed to return empty results;
 * the browser degrades to browsing the transcript list without full-text
 * ranking.
 */

#ifndef GS_SEARCHKIT_H
#define GS_SEARCHKIT_H

#import <Foundation/Foundation.h>

// SearchKit and CoreFoundation types.  CQCompatibility.h (pulled in via
// ChatCore, usually after this header) also defines some of these; guard
// against redefinition.
#ifndef CFIndex
typedef unsigned long CFIndex;
#endif
#ifndef CFStringRef
typedef NSString *CFStringRef;
#endif
#ifndef CFAllocatorRef
typedef void *CFAllocatorRef;
#endif
#ifndef Boolean
typedef unsigned char Boolean;
#endif
#ifndef CFDictionaryRef
typedef NSDictionary *CFDictionaryRef;
#endif
typedef void *CFURLRef;
typedef void *CFArrayRef;
typedef void *CFMutableArrayRef;
typedef struct {
	unsigned long location;
	unsigned long length;
} CFRange;
static inline CFRange CFRangeMake(unsigned long loc, unsigned long len) {
	CFRange r; r.location = loc; r.length = len; return r;
}

extern const void *kCFTypeArrayCallBacks;
CFArrayRef CFArrayCreate(CFAllocatorRef allocator, const void **values, CFIndex numValues, const void *callBacks);

typedef void *SKIndexRef;
typedef void *SKSearchGroupRef;
typedef void *SKSearchResultsRef;
typedef void *SKDocumentRef;

enum {
	kSKIndexInverted = 0
};

enum {
	kSKSearchPrefixRanked = 0
};

SKIndexRef SKIndexOpenWithURL(CFURLRef url, CFStringRef bundleIdentifier, Boolean readOnly);
SKIndexRef SKIndexCreateWithURL(CFURLRef url, CFStringRef bundleIdentifier, int indexType, CFDictionaryRef analyzerOptions);
void SKIndexClose(SKIndexRef index);
void SKIndexFlush(SKIndexRef index);
SKSearchGroupRef SKSearchGroupCreate(CFArrayRef indexes);
void SKSearchGroupDestroy(SKSearchGroupRef group);
void SKIndexAddDocumentWithText(SKIndexRef index, SKDocumentRef document, CFStringRef text, Boolean canReplace);

SKSearchResultsRef SKSearchResultsCreateWithQuery(SKSearchGroupRef group, CFStringRef query, int searchFlags, CFIndex maxCount, void *timeRange, void *cancelWithMonitor);
CFIndex SKSearchResultsGetCount(SKSearchResultsRef results);
void SKSearchResultsGetInfoInRange(SKSearchResultsRef results, CFRange range, SKDocumentRef *outDocuments, void *outScores, float *outScoresFloat);

SKDocumentRef SKDocumentCreateWithURL(CFURLRef url);
CFURLRef SKDocumentCopyURL(SKDocumentRef document);

#endif