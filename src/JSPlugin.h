#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"
#import "JSMBaseCodaPlugin.h"

#import "JSMDb.h"
#import "JSMdropView.h"
#import "JSMkeyPrefButton.h"
#import "JSMsiteSettingsWindowController.h"
#import "JSMpreferenceWindowController.h"

#import "JSMTaskMan.h"

@interface JSPlugin : JSMBaseCodaPlugin <CodaPlugIn, NSUserNotificationCenterDelegate, NSWindowDelegate, LessDbDelegate>
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

#pragma mark - preferences Window

//@property (strong) IBOutlet NSView *preferenceWindow;
//@property (strong) IBOutlet NSTextField *versionField;
//@property (strong) IBOutlet NSTextField *LESSVersionField;

//- (IBAction)userChangedPreference:(NSButton *)sender;
//- (IBAction)viewGithub:(id)sender;

@end
