/*
 * CQCompatibility.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GNUstep portability header for Colloquy Chat Core.  Shims Apple-only and
 * libdispatch (GCD) APIs used by Chat Core onto GNUstep equivalents:
 *
 *   - dispatch_* functions  -> CQSerialQueue
 *   - GCDAsyncSocket        -> CQAsyncSocket
 *   - Security (SecTrust)   -> always-trust stubs
 *   - SystemConfiguration   -> always-reachable stubs
 *   - CoreFoundation        -> GNUstep object shims
 *
 * Include this header from every Chat Core source file (via the build's
 * ADDITIONAL_CPPFLAGS -include option) instead of @import CocoaAsyncSocket.
 */

#ifndef CQCOMPATIBILITY_H
#define CQCOMPATIBILITY_H

#import <Foundation/Foundation.h>

// ---- Apple nullability qualifiers (GNUstep lacks __nullable/__nonnull) ----
// Colloquy sources use _Nonnull/_Nullable directly after the source header
// patch; no macro shims needed here.

// ---- Apple annotation macros not provided by GNUstep ----------------------
#ifndef NS_REQUIRES_SUPER
#define NS_REQUIRES_SUPER __attribute__((objc_requires_super))
#endif
#ifndef NS_RETURNS_RETAINED
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
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

#ifndef OSType
#define OSType uint32_t
#endif

// ---- Target conditionals (Apple-only; default everything off) -------------
#ifndef TARGET_OS_IPHONE
#define TARGET_OS_IPHONE 0
#endif
#ifndef TARGET_OS_OSX
#define TARGET_OS_OSX 1
#endif

// ---------------------------------------------------------------------------
// libdispatch (GCD) shim -> CQSerialQueue
//
// GNUstep ships libdispatch headers, but the project avoids libdispatch as
// unreliable.  Provide serial queues via CQSerialQueue instead.  The source
// files are patched to call the CQQueue* functions below in place of the
// dispatch_* functions (macros cannot be used here because dispatch blocks
// contain commas that would split macro arguments).
// ---------------------------------------------------------------------------
#import "CQSerialQueue.h"

static inline dispatch_queue_t CQQueueCreate(const char *name, void *attr) {
	(void)attr;
	return (dispatch_queue_t)(__bridge void *)[[CQSerialQueue alloc] initWithName: [NSString stringWithUTF8String: name ?: ""]];
}

static inline dispatch_queue_t CQQueueMain(void) {
	return (dispatch_queue_t)(__bridge void *)[CQSerialQueue mainQueue];
}

static inline void CQQueueAsync(dispatch_queue_t q, void (^block)(void)) {
	[(__bridge CQSerialQueue *)(q) async: (CQSerialQueueBlock)block];
}

static inline void CQQueueSync(dispatch_queue_t q, void (^block)(void)) {
	[(__bridge CQSerialQueue *)(q) sync: (CQSerialQueueBlock)block];
}

static inline dispatch_time_t CQQueueTime(dispatch_time_t now, int64_t delta) {
	(void)now;
	return (dispatch_time_t)((double)delta / (double)NSEC_PER_SEC);
}

static inline void CQQueueAfter(dispatch_time_t delay, dispatch_queue_t q, void (^block)(void)) {
	[(__bridge CQSerialQueue *)(q) afterDelay: (double)delay block: (CQSerialQueueBlock)block];
}

static inline void CQQueueOnce(long *token, void (^block)(void)) {
	if (*token == 0) {
		*token = 1;
		block();
	}
}

static inline void CQQueueRelease(dispatch_queue_t q) {
	(void)q; // queue objects are ARC-managed
}

// ---- GCDAsyncSocket -> CQAsyncSocket --------------------------------------
#import "CQAsyncSocket.h"

#define GCDAsyncSocket CQAsyncSocket
#define GCDAsyncSocketDelegate CQAsyncSocketDelegate

#define GCDAsyncSocketSSLSessionOptionSendOneByteRecord @"CQSendOneByteRecord"
#define GCDAsyncSocketSSLSessionOptionFalseStart @"CQFalseStart"
#define GCDAsyncSocketManuallyEvaluateTrust @"CQManuallyEvaluateTrust"

// ---- Security (SecTrust) stubs --------------------------------------------
typedef struct __SecTrust *SecTrustRef;
typedef uint32_t SecTrustResultType;

#ifndef kSecTrustResultProceed
#define kSecTrustResultProceed 1
#endif
#ifndef kSecTrustResultUnspecified
#define kSecTrustResultUnspecified 4
#endif

static inline void SecTrustEvaluateAsync(SecTrustRef trust, dispatch_queue_t queue,
                                         void (^handler)(SecTrustRef, SecTrustResultType)) {
	(void)trust;
	(void)queue;
	if (handler) handler(trust, kSecTrustResultUnspecified);
}

#endif // CQCOMPATIBILITY_H
