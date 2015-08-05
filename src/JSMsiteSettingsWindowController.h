//
//  siteSettingsWindowController.h
//  LESSCompile
//
//  Created by Michael on 10/29/14.
//
//

#import <Cocoa/Cocoa.h>
#import "JSMdropView.h"
#import "FileView.h"
#import "JSMflippedView.h"

@class JSMDb;

@interface JSMsiteSettingsWindowController : NSWindowController <NSWindowDelegate, DraggingDestinationDelegate>
{
    JSMDb * Ldb;
    NSMutableArray * fileViews;
    NSView * fileDocumentView;
    NSView * fileDocumentSubview;
}
@property (strong) IBOutlet NSButton *addFileButton;
@property (strong) IBOutlet NSScrollView *fileScrollView;
@property (strong) IBOutlet JSMdropView *fileDropView;
- (IBAction)filePressed:(NSButton *)sender;
@end
