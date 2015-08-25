//
//  FileView.h
//  JSMinify
//
//  Created by Michael on 10/30/13.
//
//

#import <Cocoa/Cocoa.h>
@class JSMkeyPrefButton;

@interface JSMFileView : NSView
@property (strong) IBOutlet NSTextField *fileName;
@property (strong) IBOutlet NSTextField *jsPath;
@property (strong) IBOutlet NSTextField *minifiedPath;
@property (strong) IBOutlet NSButton *changeCssPathButton;
@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) IBOutlet NSButton *advancedButton;

@property (assign) NSInteger fileIndex;
@property (strong) IBOutlet NSView *advancedSettingsView;
@property BOOL isAdvancedToggled;
@property (strong) IBOutlet NSBox *horizontalLine;

/* compilation options */

@property (strong) IBOutlet JSMkeyPrefButton *sourceMap;
@property (strong) IBOutlet JSMkeyPrefButton *noIE;
@property (strong) IBOutlet JSMkeyPrefButton *strictImports;
@property (strong) IBOutlet JSMkeyPrefButton *insecureImports;
@property (strong) IBOutlet JSMkeyPrefButton *disableJavascript;

-(void) setupOptionsWithSelector:(SEL)aSelector andTarget:(id)target;
-(void) setCheckboxesForOptions:(NSDictionary *)options;
-(NSDictionary *) getOptionValues;
@end
