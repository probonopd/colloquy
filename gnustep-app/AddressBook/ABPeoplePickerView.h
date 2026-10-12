/*
 * ABPeoplePickerView.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Inert stub for the Address Book framework.  GNUstep has no address book; the
 * buddy list falls back to manual entries, so the picker is never shown and the
 * classes exist only so the upstream sources compile.
 */

#ifndef GS_ABPEOPLEPICKERVIEW_H
#define GS_ABPEOPLEPICKERVIEW_H

#import <Cocoa/Cocoa.h>

// Address Book property keys used by MVBuddyListController.
#define kABNicknameProperty @"Nickname"
#define kABFirstNameProperty @"First"
#define kABLastNameProperty @"Last"
#define kABEmailProperty @"Email"
#define kABInstantMessageProperty @"InstantMessage"
#define kABSocialProfileProperty @"SocialProfile"

@class ABPerson;
@class ABRecord;
@class ABMultiValue;

@class ABPerson;

// The buddy avatar is fetched asynchronously on macOS; the client protocol is
// declared before ABPerson so -beginLoadingImageDataForClient: can name it.
@protocol ABImageClient
@optional
- (void) consumeImageData:(NSData *)data forTag:(NSInteger)tag;
@end

@interface ABPerson : NSObject
+ (ABPerson *) person;
// Multi-value properties (e-mail, instant message) return an ABMultiValue, so
// the return type has to stay untyped as it is in the Address Book framework.
- (id) valueForProperty:(NSString *)property;
- (void) setValue:(id)value forProperty:(NSString *)property;
- (NSString *) uniqueId;
- (NSString *) displayName;
- (NSData *) imageData;
- (NSInteger) beginLoadingImageDataForClient:(id <ABImageClient>)client;
@end

@interface ABMultiValue : NSObject
- (NSArray *) values;
- (NSUInteger) count;
- (id) valueAtIndex:(NSUInteger)index;
- (id) primaryIdentifier;
- (NSUInteger) indexForIdentifier:(id)identifier;
- (NSString *) labelAtIndex:(NSUInteger)index;
@end

@interface ABAddressBook : NSObject
+ (ABAddressBook *) sharedAddressBook;
- (ABPerson *) recordForUniqueId:(NSString *)uniqueId;
- (NSArray *) people;
- (ABPerson *) me;
@end

@interface ABPeoplePickerView : NSView
- (NSArray *) selectedRecords;
- (NSArray *) selectedValues;
- (void) setAllowsMultipleSelection:(BOOL)flag;
- (BOOL) allowsMultipleSelection;
- (void) setAllowsGroupSelection:(BOOL)flag;
- (void) setTarget:(id)target;
- (void) setAction:(SEL)action;
- (void) setNameDoubleAction:(SEL)action;
- (void) addProperty:(NSString *)property;
@end

#endif // GS_ABPEOPLEPICKERVIEW_H