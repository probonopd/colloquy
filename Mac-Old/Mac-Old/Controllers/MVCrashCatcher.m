#import "MVCrashCatcher.h"

// GNUstep has no DiagnosticReports crash-log infrastructure and no sysctl
// hardware model query.  The crash catcher is only invoked after a previous
// crash report was written; there are none on GNUstep, so the class is inert.

@implementation MVCrashCatcher
+ (void) check {
}

// The report panel is never brought up, so its buttons are never pressed.
- (IBAction) sendCrashLog:(id) sender { (void)sender; }
- (IBAction) dontSend:(id) sender { (void)sender; }
@end