/*
 * CQSerialQueue.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * A serial block-execution queue for GNUstep, used as a drop-in replacement
 * for the libdispatch (GCD) serial queues Colloquy Chat Core uses.  Blocks
 * are executed in FIFO order on a dedicated thread that runs a runloop, so
 * the design stays within the GNUstep thread + runloop model.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

@class NSThread;
@class NSLock;
@class NSMutableArray;
@class NSConditionLock;

typedef void (^CQSerialQueueBlock)(void);

@interface CQSerialQueue : NSObject
{
	NSThread *_thread;
	NSLock *_queueLock;
	NSMutableArray *_pendingBlocks;
	NSMutableArray *_delayedBlocks;
	NSConditionLock *_wakeLock;
	NSString *_name;
	BOOL _stop;
	BOOL _isMainQueue;
}

+ (CQSerialQueue *) mainQueue;
+ (CQSerialQueue *) serialQueueWithName: (NSString *)name;

- (instancetype) initWithName: (NSString *)name;

- (void) async: (CQSerialQueueBlock)block;
- (void) sync: (CQSerialQueueBlock)block;
- (void) afterDelay: (NSTimeInterval)delay block: (CQSerialQueueBlock)block;

- (BOOL) isCurrentQueue;

@end
