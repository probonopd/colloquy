/*
 * Security.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Inert stub for the macOS Security framework's keychain API.  GNUstep has
 * no keychain; lookups return errSecItemNotFound and deletions are no-ops so
 * the password helpers in MVKeyChain fail gracefully.
 */

#ifndef GS_SECURITY_H
#define GS_SECURITY_H

#import <Foundation/Foundation.h>

typedef int OSStatus;
typedef uint32_t SecProtocolType;
typedef uint32_t SecAuthenticationType;
typedef void * SecKeychainItemRef;
typedef void * SecKeychainSearchRef;
typedef void * SecAccessRef;

enum {
	errSecSuccess = 0,
	errSecItemNotFound = -25300,
	errSecParam = -50,
	errSecInvalidItemRef = -25260,
	noErr = 0
};

enum {
	kSecProtocolFTP = 0,
	kSecProtocolHTTP = 0x0002,
	kSecProtocolIRC = 0x0003,
	kSecProtocolSMTP = 0x0004,
	kSecProtocolHTTPS = 0x0005,
	kSecProtocolIMAP = 0x0006,
	kSecProtocolPOP3 = 0x0007,
	kSecProtocolSMTPS = 0x0008,
	kSecProtocolIMAPS = 0x0009
};

// The kSecProtocolType* spelling used by MVKeyChain.h, mapped onto the same
// values as the kSecProtocol* constants above.
enum {
	kSecProtocolTypeFTP = 0,
	kSecProtocolTypeFTPAccount = 0x0001,
	kSecProtocolTypeHTTP = 0x0002,
	kSecProtocolTypeIRC = 0x0003,
	kSecProtocolTypeSMTP = 0x0004,
	kSecProtocolTypeHTTPS = 0x0005,
	kSecProtocolTypeIMAP = 0x0006,
	kSecProtocolTypePOP3 = 0x0007,
	kSecProtocolTypeSMTPS = 0x0008,
	kSecProtocolTypeIMAPS = 0x0009,
	kSecProtocolTypeNNTP = 0x000A,
	kSecProtocolTypeSOCKS = 0x000B,
	kSecProtocolTypeLDAP = 0x000C,
	kSecProtocolTypeAppleTalk = 0x000D,
	kSecProtocolTypeAFP = 0x000E,
	kSecProtocolTypeTelnet = 0x000F,
	kSecProtocolTypeSSH = 0x0010
};

enum {
	kSecAuthenticationTypeAny = 0,
	kSecAuthenticationTypeNTLM = 0x000A,
	kSecAuthenticationTypeDefault = 0x000B,
	kSecAuthenticationTypeMSN = 0x000C,
	kSecAuthenticationTypeDPA = 0x000D,
	kSecAuthenticationTypeRPA = 0x000E,
	kSecAuthenticationTypeHTTPDigest = 0x000F
};

extern OSStatus SecKeychainFindGenericPassword(const void *keychainOrArray,
	unsigned int serviceNameLength, const char *serviceName,
	unsigned int accountNameLength, const char *accountName,
	unsigned int *passwordLength, void **passwordData, SecKeychainItemRef *itemRef);
extern OSStatus SecKeychainFindInternetPassword(const void *keychainOrArray,
	unsigned int serverNameLength, const char *serverName,
	unsigned int securityDomainLength, const char *securityDomain,
	unsigned int accountNameLength, const char *accountName,
	unsigned int pathLength, const char *path,
	unsigned short port, SecProtocolType protocol, unsigned int authType,
	unsigned int *passwordLength, void **passwordData, SecKeychainItemRef *itemRef);
extern OSStatus SecKeychainItemFreeContent(void *attrList, void *data);
extern OSStatus SecKeychainItemDelete(SecKeychainItemRef itemRef);
extern OSStatus SecKeychainAddGenericPassword(const void *keychain,
	unsigned int serviceNameLength, const char *serviceName,
	unsigned int accountNameLength, const char *accountName,
	unsigned int passwordLength, const void *passwordData,
	SecKeychainItemRef *itemRef);
extern OSStatus SecKeychainAddInternetPassword(const void *keychain,
	unsigned int serverNameLength, const char *serverName,
	unsigned int securityDomainLength, const char *securityDomain,
	unsigned int accountNameLength, const char *accountName,
	unsigned int pathLength, const char *path,
	unsigned short port, SecProtocolType protocol, unsigned int authType,
	unsigned int passwordLength, const void *passwordData,
	SecKeychainItemRef *itemRef);

#endif // GS_SECURITY_H