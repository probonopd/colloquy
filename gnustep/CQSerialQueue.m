/*
 * CQSerialQueue.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>

#import "CQSerialQueue.h"

@implementation CQSerialQueue

+ (CQSerialQueue *) mainQueue {
	static CQSerialQueue *queue = nil;
	static NSLock *lock = nil;
	if (!queue) {
		if (!lock) {
			lock = [[NSLock alloc] init];
		}
		[lock lock];
		if (!queue) {
			queue = [[CQSerialQueue alloc] initWithName: @"main"];
			queue->_isMainQueue = YES;
			queue->_thread = [NSThread mainThread];
		}
		[lock unlock];
	}
	return queue;
}

+ (CQSerialQueue *) serialQueueWithName: (NSString *)name {
	return [[CQSerialQueue alloc] initWithName: name];
}

- (instancetype) initWithName: (NSString *)name {
	if ((self = [super init])) {
		_name = [name copy];
		_queueLock = [[NSLock alloc] init];
		_wakeLock = [[NSConditionLock alloc] initWithCondition: 0];
		_pendingBlocks = [[NSMutableArray alloc] init];
		_delayedBlocks = [[NSMutableArray alloc] init];
		_thread = [[NSThread alloc] initWithTarget: self selector: @selector(_runLoop) object: nil];
		[_thread start];
	}
	return self;
}

- (void) dealloc {
	if (!_isMainQueue) {
		[_queueLock lock];
		_stop = YES;
		[_queueLock unlock];
		[_wakeLock lock];
		[_wakeLock unlockWithCondition: 1];
	}
}

- (BOOL) isCurrentQueue {
	return [_thread isEqual: [NSThread currentThread]];
}

- (void) async: (CQSerialQueueBlock)block {
	if (!block) return;
	// Running inline avoids deadlocking on _wakeLock when a block that is
	// already executing on this queue enqueues more work.
	if ([self isCurrentQueue]) {
		block();
		return;
	}
	if (_isMainQueue) {
		[self performSelectorOnMainThread: @selector(_runMainBlock:)
		                      withObject: [block copy]
		                   waitUntilDone: NO];
		return;
	}
	[_queueLock lock];
	[_pendingBlocks addObject: [block copy]];
	[_queueLock unlock];
	[self _signalWakeup];
}

- (void) sync: (CQSerialQueueBlock)block {
	if ([self isCurrentQueue]) {
		block();
		return;
	}
	NSConditionLock *done = [[NSConditionLock alloc] initWithCondition: 0];
	[self async: ^{
		block();
		[done lock];
		[done unlockWithCondition: 1];
	}];
	[done lockWhenCondition: 1];
	[done unlock];
}

// Schedules a block to run on this queue after the given delay.  The queue
// thread is never blocked: _runLoop waits with a deadline instead, so the
// queue keeps servicing ordinary blocks while the delay is outstanding.
- (void) afterDelay: (NSTimeInterval)delay block: (CQSerialQueueBlock)block {
	if (!block) return;
	if (_isMainQueue) {
		// The main thread runs a real run loop, so use a timer on it rather
		// than the delayed-blocks mechanism used by worker queues.
		NSDictionary *info = @{ @"delay": @(delay), @"block": [block copy] };
		[self performSelectorOnMainThread: @selector(_scheduleMainDelay:)
		                      withObject: info
		                   waitUntilDone: NO];
		return;
	}
	NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow: delay];
	NSDictionary *entry = @{ @"date": fireDate, @"block": [block copy] };
	[_queueLock lock];
	[_delayedBlocks addObject: entry];
	[_queueLock unlock];
	// Wake the queue thread so it recomputes its wait deadline.
	[self _signalWakeup];
}

- (void) _scheduleMainDelay: (NSDictionary *)info {
	// Runs on the main thread; schedules the block on the main run loop.
	NSTimeInterval delay = [[info objectForKey: @"delay"] doubleValue];
	[self performSelector: @selector(_runMainBlock:)
	           withObject: [info objectForKey: @"block"]
	           afterDelay: delay];
}

- (void) _runMainBlock: (CQSerialQueueBlock)block {
	@autoreleasepool {
		if (block) block();
	}
}

// Wakes _runLoop.  Must be called from outside the queue thread.
- (void) _signalWakeup {
	[_wakeLock lock];
	if ([_wakeLock condition] == 0) {
		[_wakeLock unlockWithCondition: 1];
	} else {
		[_wakeLock unlock];
	}
}

- (NSDate *) _earliestDelayedFireDate {
	NSDate *earliest = nil;
	for (NSDictionary *entry in _delayedBlocks) {
		NSDate *date = [entry objectForKey: @"date"];
		if (!earliest || [date compare: earliest] == NSOrderedAscending)
			earliest = date;
	}
	return earliest;
}

- (void) _runLoop {
	@autoreleasepool {
		while (YES) {
			NSDate *nextFire = nil;
			BOOL stopped = NO;
			[_queueLock lock];
			if (_stop) {
				stopped = YES;
			} else {
				nextFire = [self _earliestDelayedFireDate];
			}
			[_queueLock unlock];
			if (stopped) break;

			// Wait until either a block is enqueued (condition 1) or the
			// earliest delayed block becomes due.  We do NOT hold _wakeLock
			// while running blocks, so producers never block behind user
			// code; the add-then-signal ordering in async: and afterDelay:
			// guarantees no lost wakeups.
			NSDate *waitUntil = (nextFire ? nextFire : [NSDate distantFuture]);
			if ([_wakeLock lockWhenCondition: 1 beforeDate: waitUntil]) {
				// Consume the wakeup we acquired.
				[_wakeLock unlockWithCondition: 0];
			}

			NSDate *now = [NSDate date];
			NSMutableArray *due = [[NSMutableArray alloc] init];
			NSArray *pending = nil;
			[_queueLock lock];
			NSMutableIndexSet *dueIndexes = [NSMutableIndexSet indexSet];
			NSUInteger index = 0;
			for (NSDictionary *entry in _delayedBlocks) {
				if ([[entry objectForKey: @"date"] compare: now] != NSOrderedDescending) {
					[due addObject: [entry objectForKey: @"block"]];
					[dueIndexes addIndex: index];
				}
				index++;
			}
			[_delayedBlocks removeObjectsAtIndexes: dueIndexes];
			if ([_pendingBlocks count] > 0) {
				pending = [_pendingBlocks copy];
				[_pendingBlocks removeAllObjects];
			}
			[_queueLock unlock];

			for (CQSerialQueueBlock block in due) {
				@autoreleasepool {
					block();
				}
			}
			for (CQSerialQueueBlock block in pending) {
				@autoreleasepool {
					block();
				}
			}
		}
	}
}

@end
