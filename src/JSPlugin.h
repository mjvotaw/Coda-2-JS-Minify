#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"
#import "JSMBaseCodaPlugin.h"

#import "JSMDb.h"
#import "JSMdropView.h"
#import "JSMkeyPrefButton.h"
#import "JSMsiteSettingsWindowController.h"
#import "JSMpreferenceWindowController.h"

#import "JSMTaskMan.h"

@interface JSPlugin : JSMBaseCodaPlugin <CodaPlugIn, NSUserNotificationCenterDelegate, NSWindowDelegate, JSDbDelegate>
{
    
    JSMTaskMan * task;
    NSString * outputText;
    NSString * errorText;
    
    JSMsiteSettingsWindowController * siteSettingsController;
    JSMpreferenceWindowController * preferenceController;
    JSMDb * Ldb;
    
	BOOL isCompiling;
	int compileCount;
}

@end
