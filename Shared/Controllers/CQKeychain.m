#import "CQKeychain.h"

NS_ASSUME_NONNULL_BEGIN

// GNUstep has no secure keychain service. The upstream CQKeychain was stubbed to
// a no-op, and MVKeyChain relies on macOS SecKeychain APIs that do not exist on
// GNUstep, so passwords (server and SASL) could never be persisted or read back.
// We implement CQKeychain with a plaintext property-list store under the user's
// Library/Preferences directory. This is the documented GNUstep fallback: it is
// not encrypted, but it is the only viable option without a platform keychain.
@implementation CQKeychain {
	NSMutableDictionary *_passwords;
	NSMutableDictionary *_data;
	NSString *_path;
}

+ (CQKeychain *) standardKeychain {
	static CQKeychain *sharedInstance;
	if (!sharedInstance) sharedInstance = [[self alloc] init];
	return sharedInstance;
}

- (instancetype) init {
	if ((self = [super init])) {
		NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences"];
		_path = [dir stringByAppendingPathComponent: @"ColloquyKeychain.plist"];
		_passwords = [NSMutableDictionary dictionary];
		_data = [NSMutableDictionary dictionary];
		[self _load];
	}
	return self;
}

- (NSString *) _keyForServer: (NSString *) server area: (NSString *) area {
	return [NSString stringWithFormat: @"%@\n%@", (server ?: @""), (area ?: @"")];
}

- (void) _load {
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath: _path]) {
		NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: _path];
		if (dict) {
			id pw = [dict objectForKey: @"passwords"];
			id dt = [dict objectForKey: @"data"];
			_passwords = ([pw isKindOfClass: [NSDictionary class]] ? [pw mutableCopy] : [NSMutableDictionary dictionary]);
			_data = ([dt isKindOfClass: [NSDictionary class]] ? [dt mutableCopy] : [NSMutableDictionary dictionary]);
		}
	}
}

- (void) _save {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir = [_path stringByDeletingLastPathComponent];
	if (![fm fileExistsAtPath: dir])
		[fm createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
	NSDictionary *dict = @{ @"passwords": _passwords, @"data": _data };
	[dict writeToFile: _path atomically: YES];
}

- (void) setPassword: (NSString *) password forServer: (NSString *) server area: (NSString *) area {
	[_passwords setObject: (password ?: @"") forKey: [self _keyForServer: server area: area]];
	[self _save];
}

- (void) setPassword: (NSString *) password forServer: (NSString *) server area: (NSString *) area displayValue: (NSString *__nullable) displayValue {
	[self setPassword: password forServer: server area: area];
}

- (NSString *__nullable) passwordForServer: (NSString *) server area: (NSString *) area {
	return [_passwords objectForKey: [self _keyForServer: server area: area]];
}

- (void) removePasswordForServer: (NSString *) server area: (NSString *) area {
	[_passwords removeObjectForKey: [self _keyForServer: server area: area]];
	[self _save];
}

- (void) setData: (NSData *) passwordData forServer: (NSString *) server area: (NSString *) area {
	[_data setObject: (passwordData ?: [NSData data]) forKey: [self _keyForServer: server area: area]];
	[self _save];
}

- (void) setData: (NSData *) passwordData forServer: (NSString *) server area: (NSString *) area displayValue: (NSString *__nullable) displayValue {
	[self setData: passwordData forServer: server area: area];
}

- (NSData *__nullable) dataForServer: (NSString *) server area: (NSString *) area {
	return [_data objectForKey: [self _keyForServer: server area: area]];
}

- (void) removeDataForServer: (NSString *) server area: (NSString *) area {
	[_data removeObjectForKey: [self _keyForServer: server area: area]];
	[self _save];
}
@end

NS_ASSUME_NONNULL_END
