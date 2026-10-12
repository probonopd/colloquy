/*
 * SearchKit.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Stub implementations for the SearchKit shim in SearchKit.h.  GNUstep has no
 * Spotlight, so the transcript browser's full-text ranking is a no-op: the
 * index never stores anything and searches return zero results.
 */

#import "SearchKit.h"

const void *kCFTypeArrayCallBacks = (const void *)&kCFTypeArrayCallBacks;

CFArrayRef CFArrayCreate(CFAllocatorRef allocator, const void **values, CFIndex numValues, const void *callBacks) {
	(void)allocator; (void)values; (void)numValues; (void)callBacks;
	return NULL;
}

SKIndexRef SKIndexOpenWithURL(CFURLRef url, CFStringRef bundleIdentifier, Boolean readOnly) {
	(void)url; (void)bundleIdentifier; (void)readOnly;
	return NULL;
}

SKIndexRef SKIndexCreateWithURL(CFURLRef url, CFStringRef bundleIdentifier, int indexType, CFDictionaryRef analyzerOptions) {
	(void)url; (void)bundleIdentifier; (void)indexType; (void)analyzerOptions;
	return NULL;
}

void SKIndexClose(SKIndexRef index) {
	(void)index;
}

void SKIndexFlush(SKIndexRef index) {
	(void)index;
}

SKSearchGroupRef SKSearchGroupCreate(CFArrayRef indexes) {
	(void)indexes;
	return NULL;
}

void SKSearchGroupDestroy(SKSearchGroupRef group) {
	(void)group;
}

void SKIndexAddDocumentWithText(SKIndexRef index, SKDocumentRef document, CFStringRef text, Boolean canReplace) {
	(void)index; (void)document; (void)text; (void)canReplace;
}

SKSearchResultsRef SKSearchResultsCreateWithQuery(SKSearchGroupRef group, CFStringRef query, int searchFlags, CFIndex maxCount, void *timeRange, void *cancelWithMonitor) {
	(void)group; (void)query; (void)searchFlags; (void)maxCount; (void)timeRange; (void)cancelWithMonitor;
	return NULL;
}

CFIndex SKSearchResultsGetCount(SKSearchResultsRef results) {
	(void)results;
	return 0;
}

void SKSearchResultsGetInfoInRange(SKSearchResultsRef results, CFRange range, SKDocumentRef *outDocuments, void *outScores, float *outScoresFloat) {
	(void)results; (void)range; (void)outDocuments; (void)outScores; (void)outScoresFloat;
}

SKDocumentRef SKDocumentCreateWithURL(CFURLRef url) {
	(void)url;
	return NULL;
}

CFURLRef SKDocumentCopyURL(SKDocumentRef document) {
	(void)document;
	return NULL;
}