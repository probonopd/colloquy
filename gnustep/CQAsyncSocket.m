/*
 * CQAsyncSocket.m
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <GNUstepBase/GSTLS.h>

#import "CQAsyncSocket.h"
#import "CQSerialQueue.h"

@implementation CQAsyncSocket {
	NSData *_pendingReadData;
	NSUInteger _pendingReadLength;
	long _pendingReadTag;
	NSInteger _pendingReadMode; // 1=toData 2=toLength 3=withTimeout
}

+ (NSData *) LFData {
	static NSData *lfData = nil;
	if (!lfData)
		lfData = [[NSData alloc] initWithBytes: "\n" length: 1];
	return lfData;
}

- (instancetype) initWithDelegate: (id)delegate
                    delegateQueue: (dispatch_queue_t)delegateQueue
                      socketQueue: (dispatch_queue_t)socketQueue {
	if ((self = [super init])) {
		_delegate = delegate;
		if (delegateQueue) {
			_delegateQueue = (__bridge CQSerialQueue *)(delegateQueue);
		} else {
			_delegateQueue = [CQSerialQueue mainQueue];
		}
		_readBuffer = [[NSMutableData alloc] init];
		_writeBuffer = [[NSMutableData alloc] init];
		_isIPv6Enabled = YES;
		_isIPv4PreferredOverIPv6 = YES;
	}
	return self;
}

@synthesize delegate = _delegate;
@synthesize userData = _userData;
@synthesize IPv6Enabled = _isIPv6Enabled;
@synthesize IPv4PreferredOverIPv6 = _isIPv4PreferredOverIPv6;
@synthesize connected = _isConnected;
@synthesize connectedHost = _connectedHost;
@synthesize connectedPort = _connectedPort;

- (BOOL) isConnected {
	return _isConnected;
}

- (BOOL) tlsEnabled {
	return _tlsEnabled;
}

- (void) setTlsEnabled: (BOOL)enabled {
	_tlsEnabled = enabled;
}

#pragma mark Connection

- (BOOL) connectToHost: (NSString *)host onPort: (UInt16)port error: (NSError **)errPtr {
	NSInputStream *input = nil;
	NSOutputStream *output = nil;

	// Resolve the host ourselves so we can choose the address family.
	// Our IPv4 egress is DroneBL-listed by some IRC networks, so we must
	// connect over IPv6; otherwise the server rejects the connection.
	NSString *chosen = nil;
	{
		struct addrinfo hints, *res = NULL, *ai = NULL;
		memset(&hints, 0, sizeof(hints));
		hints.ai_family = AF_UNSPEC;
		hints.ai_socktype = SOCK_STREAM;
		if (getaddrinfo([host UTF8String], NULL, &hints, &res) == 0) {
			NSMutableArray *v6 = [NSMutableArray array];
			NSMutableArray *v4 = [NSMutableArray array];
			for (ai = res; ai; ai = ai->ai_next) {
				char buf[INET6_ADDRSTRLEN];
				if (ai->ai_family == AF_INET6) {
					struct sockaddr_in6 *s = (struct sockaddr_in6 *)ai->ai_addr;
					if (inet_ntop(AF_INET6, &s->sin6_addr, buf, sizeof(buf)) && strncmp(buf, "fe80", 4))
						[v6 addObject: [NSString stringWithUTF8String: buf]];
				} else if (ai->ai_family == AF_INET) {
					struct sockaddr_in *s = (struct sockaddr_in *)ai->ai_addr;
					if (inet_ntop(AF_INET, &s->sin_addr, buf, sizeof(buf)))
						[v4 addObject: [NSString stringWithUTF8String: buf]];
				}
			}
			freeaddrinfo(res);
			if (_isIPv6Enabled && v6.count) chosen = [v6 firstObject];
			else if (v4.count) chosen = [v4 firstObject];
			else if (v6.count) chosen = [v6 firstObject];
		}
	}
	if (!chosen) chosen = host;

	NSHost *nsHost = [NSHost hostWithAddress: chosen];
	[NSStream getStreamsToHost: nsHost
	                      port: port
	               inputStream: &input
	              outputStream: &output];
	if (!input || !output) {
		if (errPtr) *errPtr = [NSError errorWithDomain: NSPOSIXErrorDomain code: EHOSTUNREACH userInfo: nil];
		return NO;
	}

	_inputStream = input;
	_outputStream = output;
	_inputStream.delegate = self;
	_outputStream.delegate = self;


	if (_tlsEnabled) {
		[_inputStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
		                   forKey: NSStreamSocketSecurityLevelKey];
		[_outputStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
		                    forKey: NSStreamSocketSecurityLevelKey];
		// We connect to a numeric address, so tell TLS to validate the
		// certificate against the original server name, not the IP literal.
		[_inputStream setProperty: host forKey: GSTLSServerName];
		[_outputStream setProperty: host forKey: GSTLSServerName];
	}

	_connectedHost = [host copy];
	_connectedPort = port;

	[self _startSocketThread];
	[self performSelector: @selector(_openStreams) onThread: _socketThread withObject: nil waitUntilDone: YES];

	return YES;
}

- (BOOL) connectToAddress: (NSData *)remoteAddr error: (NSError **)errPtr {
	if (errPtr) *errPtr = [NSError errorWithDomain: NSPOSIXErrorDomain code: EINVAL userInfo: nil];
	return NO;
}

- (void) _openStreams {
	[_inputStream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
	[_inputStream open];
	[_outputStream open];
}

- (void) writeData: (NSData *)data withTimeout: (NSTimeInterval)timeout tag: (long)tag {
	if (_disconnected || !_outputStream) return;
	NSDictionary *info = @{ @"data": data, @"tag": @(tag) };
	[self performSelector: @selector(_writeDataOnSocketThread:)
	             onThread: _socketThread
	           withObject: info
	        waitUntilDone: NO];
}

- (void) _writeDataOnSocketThread: (NSDictionary *)info {
	NSData *data = [info objectForKey: @"data"];
	@synchronized (_writeBuffer) {
		[_writeBuffer appendData: data];
	}
	if (!_writeInProgress) {
		_writeInProgress = YES;
		[self _flushWriteBuffer];
	}
}

- (void) _flushWriteBuffer {
	if (_disconnected) return;
	@synchronized (_writeBuffer) {
		if (![_writeBuffer length]) {
			_writeInProgress = NO;
			return;
		}
		NSInteger written = [_outputStream write: [_writeBuffer bytes] maxLength: [_writeBuffer length]];
		if (written > 0) {
			[_writeBuffer replaceBytesInRange: NSMakeRange(0, written) withBytes: NULL length: 0];
			if (![_writeBuffer length]) {
				_writeInProgress = NO;
				[self _delegateDidWrite];
			}
		} else if (written < 0) {
			_writeInProgress = NO;
			[self _disconnectWithError: [_outputStream streamError]];
		}
	}
}

- (void) readDataToData: (NSData *)data withTimeout: (NSTimeInterval)timeout tag: (long)tag {
	@synchronized (self) {
		_pendingReadData = [data copy];
		_pendingReadTag = tag;
		_pendingReadMode = 1;
	}
	[self performSelector: @selector(_applyPendingRead) onThread: _socketThread withObject: nil waitUntilDone: NO];
}

- (void) readDataToLength: (NSUInteger)length withTimeout: (NSTimeInterval)timeout tag: (long)tag {
	@synchronized (self) {
		_pendingReadLength = length;
		_pendingReadTag = tag;
		_pendingReadMode = 2;
	}
	[self performSelector: @selector(_applyPendingRead) onThread: _socketThread withObject: nil waitUntilDone: NO];
}

- (void) readDataWithTimeout: (NSTimeInterval)timeout tag: (long)tag {
	@synchronized (self) {
		_pendingReadTag = tag;
		_pendingReadMode = 3;
	}
	[self performSelector: @selector(_applyPendingRead) onThread: _socketThread withObject: nil waitUntilDone: NO];
}

// Runs only on the socket thread: owns all read-state mutations so the socket
// stream callback and the connection-queue re-arm can never race on _readBuffer.
- (void) _applyPendingRead {
	NSData *data = nil;
	long tag = 0;
	NSUInteger length = 0;
	NSInteger mode = 0;
	@synchronized (self) {
		data = _pendingReadData;
		tag = _pendingReadTag;
		length = _pendingReadLength;
		mode = _pendingReadMode;
		_pendingReadData = nil;
	}
	if (mode == 1) {
		_readToData = data;
		_readToLength = 0;
	} else if (mode == 2) {
		_readToData = nil;
		_readToLength = length;
	} else {
		_readToData = nil;
		_readToLength = 0;
		if ([_readBuffer length]) {
			NSData *packet = [_readBuffer copy];
			[_readBuffer setLength: 0];
			[self _delegateDidRead: packet tag: tag];
			return;
		}
	}
	_readTag = tag;
	[self _processReadBuffer];
}

- (UInt16) localPort {
	return 0;
}

- (NSString *) localHost {
	return nil;
}

- (void) _processReadBuffer {
	if (_disconnected) return;
	if (_readToData) {
		NSUInteger sepLength = [_readToData length];
		if (sepLength) {
			NSRange found = [_readBuffer rangeOfData: _readToData
			                                 options: 0
			                                   range: NSMakeRange(0, [_readBuffer length])];
			if (found.location != NSNotFound) {
				NSUInteger end = found.location + sepLength;
				NSData *packet = [_readBuffer subdataWithRange: NSMakeRange(0, end)];
				[_readBuffer replaceBytesInRange: NSMakeRange(0, end) withBytes: NULL length: 0];
				[self _delegateDidRead: packet tag: _readTag];
				_readToData = nil;
			}
		}
	} else if (_readToLength) {
		if ([_readBuffer length] >= _readToLength) {
			NSData *packet = [_readBuffer subdataWithRange: NSMakeRange(0, _readToLength)];
			[_readBuffer replaceBytesInRange: NSMakeRange(0, _readToLength) withBytes: NULL length: 0];
			[self _delegateDidRead: packet tag: _readTag];
			_readToLength = 0;
		}
	}
}

- (void) startTLS: (NSDictionary *)settings {
	[self performSelector: @selector(_startTLSOnSocketThread) onThread: _socketThread withObject: nil waitUntilDone: NO];
}

- (void) _startTLSOnSocketThread {
	[_inputStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	                   forKey: NSStreamSocketSecurityLevelKey];
	[_outputStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	                    forKey: NSStreamSocketSecurityLevelKey];
}

- (void) disconnect {
	if (_disconnected) return;
	_disconnected = YES;
	[self performSelector: @selector(_closeStreams) onThread: _socketThread withObject: nil waitUntilDone: YES];
	[self _delegateDidDisconnect: nil];
}

- (void) disconnectAfterWriting {
	[self performSelector: @selector(_disconnectAfterWritingOnSocketThread) onThread: _socketThread withObject: nil waitUntilDone: NO];
}

- (void) _disconnectAfterWritingOnSocketThread {
	[self _flushWriteBuffer];
	[self disconnect];
}

- (void) _closeStreams {
	if (_inputStream) {
		[_inputStream removeFromRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		[_inputStream close];
		_inputStream = nil;
	}
	if (_outputStream) {
		[_outputStream removeFromRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		[_outputStream close];
		_outputStream = nil;
	}
}

- (void) _startSocketThread {
	_socketThread = [[NSThread alloc] initWithTarget: self selector: @selector(_socketThreadMain) object: nil];
	[_socketThread start];
}

- (void) _socketThreadMain {
	@autoreleasepool {
		NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
		NSPort *port = [[NSPort alloc] init];
		[runLoop addPort: port forMode: NSDefaultRunLoopMode];
		while (!_disconnected) {
			[runLoop runMode: NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
		}
	}
}

#pragma mark Stream delegate

- (void) stream: (NSStream *)stream handleEvent: (NSStreamEvent)eventCode {
	switch (eventCode) {
		case NSStreamEventOpenCompleted:
			if (stream == _outputStream && !_isConnected) {
				_isConnected = YES;
				[self _delegateDidConnect];
			}
			break;
		case NSStreamEventHasBytesAvailable:
			if (stream == _inputStream) {
				uint8_t buffer[4096];
				NSInteger len;
				while (_inputStream.hasBytesAvailable && (len = [_inputStream read: buffer maxLength: sizeof(buffer)]) > 0) {
					[_readBuffer appendBytes: buffer length: len];
				}
				[self _processReadBuffer];
			}
			break;
		case NSStreamEventHasSpaceAvailable:
			if (stream == _outputStream) {
				[self _flushWriteBuffer];
			}
			break;
		case NSStreamEventErrorOccurred:
			[self _disconnectWithError: [stream streamError]];
			break;
		case NSStreamEventEndEncountered:
			[self _disconnectWithError: nil];
			break;
		default:
			break;
	}
}

#pragma mark Delegate dispatch

- (void) _delegateDidConnect {
	if (!_delegate) return;
	__weak CQAsyncSocket *weakSelf = self;
	__block NSString *host = _connectedHost;
	UInt16 port = _connectedPort;
	// Capture the delegate strongly so the queued callback cannot race the
	// delegate being deallocated on another thread before it runs.
	id delegate = _delegate;
	[_delegateQueue async: ^{
		if ([delegate respondsToSelector: @selector(socket:didConnectToHost:port:)]) {
			[delegate socket: weakSelf didConnectToHost: host port: port];
		}
	}];
}

- (void) _delegateDidRead: (NSData *)data tag: (long)tag {
	if (!_delegate) return;
	__weak CQAsyncSocket *weakSelf = self;
	id delegate = _delegate;
	[_delegateQueue async: ^{
		if ([delegate respondsToSelector: @selector(socket:didReadData:withTag:)]) {
			[delegate socket: weakSelf didReadData: data withTag: tag];
		}
	}];
}

- (void) _delegateDidWrite {
	if (!_delegate) return;
	__weak CQAsyncSocket *weakSelf = self;
	id delegate = _delegate;
	[_delegateQueue async: ^{
		if ([delegate respondsToSelector: @selector(socket:didWriteDataWithTag:)]) {
			[delegate socket: weakSelf didWriteDataWithTag: 0];
		}
	}];
}

- (void) _disconnectWithError: (NSError *)error {
	if (_disconnected) return;
	_disconnected = YES;
	[self _closeStreams];
	[self _delegateDidDisconnect: error];
}

- (void) _delegateDidDisconnect: (NSError *)error {
	if (!_delegate) return;
	__weak CQAsyncSocket *weakSelf = self;
	id delegate = _delegate;
	[_delegateQueue async: ^{
		if ([delegate respondsToSelector: @selector(socketDidDisconnect:withError:)]) {
			[delegate socketDidDisconnect: weakSelf withError: error];
		}
	}];
}

@end

@implementation CQAsyncSocket (Accept)

- (BOOL) acceptOnPort: (UInt16)port error: (NSError **)errPtr {
	return [self acceptOnInterface: nil port: port error: errPtr];
}

- (BOOL) acceptOnInterface: (NSString *)interface port: (UInt16)port error: (NSError **)errPtr {
	if (errPtr) *errPtr = [NSError errorWithDomain: NSPOSIXErrorDomain code: EOPNOTSUPP userInfo: nil];
	return NO;
}

@end
