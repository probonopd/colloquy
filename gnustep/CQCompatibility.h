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

// ---- CoreFoundation shim ---------------------------------------------------
// GNUstep base does not ship CoreFoundation headers; provide the small
// surface the IRC core needs, mapped onto GNUstep Foundation objects.

typedef unsigned long CFIndex;
typedef unsigned long CFStringEncoding;
typedef void *CFAllocatorRef;
typedef unsigned char Boolean;
typedef NSString *CFStringRef;

#define CFSTR(s) @(s)

#define kCFStringEncodingISOLatin1 ((CFStringEncoding)NSISOLatin1StringEncoding)
#define kCFStringEncodingISOLatin2 ((CFStringEncoding)NSISOLatin2StringEncoding)
#define kCFStringEncodingISOLatin3 ((CFStringEncoding)NSISOLatin3StringEncoding)
#define kCFStringEncodingISOLatin4 ((CFStringEncoding)NSISOLatin4StringEncoding)
#define kCFStringEncodingISOLatin5 ((CFStringEncoding)NSISOLatin5StringEncoding)
#define kCFStringEncodingISOLatin6 ((CFStringEncoding)NSISOLatin6StringEncoding)
#define kCFStringEncodingISOLatinCyrillic ((CFStringEncoding)NSISOCyrillicStringEncoding)
#define kCFStringEncodingISOLatinArabic ((CFStringEncoding)NSISOArabicStringEncoding)
#define kCFStringEncodingISOLatinGreek ((CFStringEncoding)NSISOGreekStringEncoding)
#define kCFStringEncodingISOLatinHebrew ((CFStringEncoding)NSISOHebrewStringEncoding)

static inline NSStringEncoding CFStringConvertEncodingToNSStringEncoding(CFStringEncoding enc) {
	return (NSStringEncoding)enc;
}

typedef struct {
	CFIndex version;
	void *retain;
	void *release;
	void *copyDescription;
	void *equal;
	void *hash;
} CQCFCallbacks;

typedef struct {
	CFIndex version;
	void *retain;
	void *release;
	void *copyDescription;
	void *equal;
} CFDictionaryValueCallBacks;

typedef struct {
	CFIndex version;
	void *retain;
	void *release;
	void *copyDescription;
	void *equal;
} CFDictionaryKeyCallBacks;

#define kCFTypeDictionaryKeyCallBacks ((CFDictionaryKeyCallBacks){0, 0, 0, 0, 0})
#define kCFTypeDictionaryValueCallBacks ((CFDictionaryValueCallBacks){0, 0, 0, 0, 0})

static inline id CQCFDictionaryCreateMutable(CFAllocatorRef allocator, CFIndex capacity,
		const void *keyCallbacks, const void *valueCallbacks) {
	(void)allocator; (void)keyCallbacks; (void)valueCallbacks;
	return [[NSMutableDictionary alloc] initWithCapacity: capacity];
}
#define CFDictionaryCreateMutable(...) CQCFDictionaryCreateMutable(__VA_ARGS__)

#define CFBridgingRelease(x) ((id)(x))
#define CFBridgingRetain(x) ((void *)(x))

#define CFRelease(x) do { (void)(x); } while (0)

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

// ---- SystemConfiguration (SCNetworkReachability) stubs --------------------
typedef CFStringRef SCNetworkReachabilityRef;
typedef uint32_t SCNetworkConnectionFlags;

typedef struct {
	CFIndex version;
	void *info;
	void (*retain)(const void *);
	void (*release)(const void *);
	void (*copyDescription)(const void *);
} SCNetworkReachabilityContext;

#ifndef kSCNetworkReachabilityFlagsIsWWAN
#define kSCNetworkReachabilityFlagsIsWWAN (1 << 18)
#endif
#ifndef kSCNetworkFlagsReachable
#define kSCNetworkFlagsReachable (1 << 1)
#endif
#ifndef kSCNetworkFlagsConnectionRequired
#define kSCNetworkFlagsConnectionRequired (1 << 2)
#endif
#ifndef kSCNetworkReachabilityFlagsReachable
#define kSCNetworkReachabilityFlagsReachable (1 << 1)
#endif

typedef void *CFRunLoopRef;

static inline SCNetworkReachabilityRef CQReachabilityCreateWithName(CFAllocatorRef a, const char *n) {
	(void)a; (void)n;
	return CFSTR("colloquy-reachability");
}
#define SCNetworkReachabilityCreateWithName(a, n) CQReachabilityCreateWithName((a), (n))

static inline Boolean CQReachabilitySetCallback(SCNetworkReachabilityRef t,
		void (*c)(SCNetworkReachabilityRef, SCNetworkConnectionFlags, void *), void *ctx) {
	(void)t; (void)c; (void)ctx;
	return true;
}
#define SCNetworkReachabilitySetCallback(t, c, ctx) CQReachabilitySetCallback((t), (c), (ctx))

static inline Boolean CQReachabilityScheduleWithRunLoop(SCNetworkReachabilityRef t,
		CFRunLoopRef rl, CFStringRef mode) {
	(void)t; (void)rl; (void)mode;
	return true;
}
#define SCNetworkReachabilityScheduleWithRunLoop(t, rl, m) CQReachabilityScheduleWithRunLoop((t), (rl), (m))

static inline void CQReachabilityUnscheduleFromRunLoop(SCNetworkReachabilityRef t,
		CFRunLoopRef rl, CFStringRef mode) {
	(void)t; (void)rl; (void)mode;
}
#define SCNetworkReachabilityUnscheduleFromRunLoop(t, rl, m) CQReachabilityUnscheduleFromRunLoop((t), (rl), (m))

static inline CFRunLoopRef CQCFRunLoopGetMain(void) { return NULL; }
#define CFRunLoopGetMain() CQCFRunLoopGetMain()
#define kCFRunLoopDefaultMode ((CFStringRef)NULL)

#endif // CQCOMPATIBILITY_H
