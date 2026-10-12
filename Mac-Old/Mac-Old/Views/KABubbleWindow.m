#import "KABubbleWindow.h"

@implementation KABubbleWindow

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(NSUInteger)aStyle
				  backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag {

	// The bubble is always borderless regardless of the style asked for.
	if( ! ( self = [super initWithContentRect:contentRect
									styleMask:NSBorderlessWindowMask
									  backing:NSBackingStoreBuffered
										defer:NO] ) )
		return nil;

	[self setBackgroundColor: [NSColor clearColor]];
	[self setLevel: NSStatusWindowLevel];
	[self setAlphaValue:0.15];
	[self setOpaque:NO];
	[self setHasShadow: YES];
	[self setCanHide:NO ];

	return self;
}

@end
