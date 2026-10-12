/*
 * CQAsyncSocket.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * A GNUstep-native asynchronous TCP socket, exposing the subset of the
 * GCDAsyncSocket API that Colloquy Chat Core uses.  Implemented on top of
 * NSStream, scheduled in a dedicated thread runloop, with delegate callbacks
 * marshaled onto a serial queue.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>
#import <stdint.h>

typedef uint16_t UInt16;

@class NSInputStream;
@class NSOutputStream;
@class NSMutableData;
@class NSMutableArray;
@class NSThread;
@class NSError;
@class NSString;
@class CQSerialQueue;

enum {
	CQAsyncSocketDefaultTag = -1
};

@interface CQAsyncSocket : NSObject
{
	__weak id _delegate;
	CQSerialQueue *_delegateQueue;
	NSInputStream *_inputStream;
	NSOutputStream *_outputStream;
	NSThread *_socketThread;
	NSMutableData *_readBuffer;
	NSData *_readToData;
	NSUInteger _readToLength;
	long _readTag;
	NSMutableArray *_pendingReads;
	NSMutableData *_writeBuffer;
	BOOL _writeInProgress;
	BOOL _disconnected;
	BOOL _isIPv6Enabled;
	BOOL _isIPv4PreferredOverIPv6;
	id _userData;
	NSString *_connectedHost;
	UInt16 _connectedPort;
	void *_acceptedFileDescriptor;
	BOOL _isConnected;
	BOOL _tlsEnabled;
}

@property (nonatomic, weak) id delegate;
@property (nonatomic, retain) id userData;
@property (nonatomic, assign) BOOL IPv6Enabled;
@property (nonatomic, assign) BOOL IPv4PreferredOverIPv6;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, assign) BOOL tlsEnabled;
@property (nonatomic, readonly, copy) NSString *connectedHost;
@property (nonatomic, readonly) UInt16 connectedPort;

+ (NSData *) LFData;

- (instancetype) initWithDelegate: (id)delegate
                    delegateQueue: (dispatch_queue_t)delegateQueue
                      socketQueue: (dispatch_queue_t)socketQueue;

- (BOOL) connectToHost: (NSString *)host onPort: (UInt16)port error: (NSError **)errPtr;
- (BOOL) connectToAddress: (NSData *)remoteAddr error: (NSError **)errPtr;

- (void) writeData: (NSData *)data withTimeout: (NSTimeInterval)timeout tag: (long)tag;
- (void) readDataToData: (NSData *)data withTimeout: (NSTimeInterval)timeout tag: (long)tag;
- (void) readDataToLength: (NSUInteger)length withTimeout: (NSTimeInterval)timeout tag: (long)tag;
- (void) readDataWithTimeout: (NSTimeInterval)timeout tag: (long)tag;

- (UInt16) localPort;
- (NSString *) localHost;

- (void) startTLS: (NSDictionary *)settings;

- (void) disconnect;
- (void) disconnectAfterWriting;

@end

@interface CQAsyncSocket (Accept)
- (BOOL) acceptOnPort: (UInt16)port error: (NSError **)errPtr;
- (BOOL) acceptOnInterface: (NSString *)interface port: (UInt16)port error: (NSError **)errPtr;
@end

@protocol CQAsyncSocketDelegate <NSObject>
@optional
- (void) socket: (CQAsyncSocket *)sock didConnectToHost: (NSString *)host port: (UInt16)port;
- (void) socket: (CQAsyncSocket *)sock didReadData: (NSData *)data withTag: (long)tag;
- (void) socket: (CQAsyncSocket *)sock didWriteDataWithTag: (long)tag;
- (void) socketDidDisconnect: (CQAsyncSocket *)sock withError: (NSError *)err;
- (void) socket: (CQAsyncSocket *)sock willDisconnectWithError: (NSError *)err;
- (void) socket: (CQAsyncSocket *)sock didAcceptNewSocket: (CQAsyncSocket *)newSocket;
@end
