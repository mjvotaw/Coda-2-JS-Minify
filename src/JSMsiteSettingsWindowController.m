//
//  siteSettingsWindowController.m
//  LESSCompile
//
//  Created by Michael on 10/29/14.
//
//

#import "JSMsiteSettingsWindowController.h"
#import "JSMDb.h"
#import "FileView.h"

@interface JSMsiteSettingsWindowController ()

@end

@implementation JSMsiteSettingsWindowController

-(instancetype)init
{
    if(self = [super initWithWindowNibName:@"JSMsiteSettingsWindowController"])
    {
        Ldb = [JSMDb sharedLessDb];
        
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.fileDropView setDelegate:self];
    [self.window setDelegate:Ldb.delegate];
    fileDocumentView = [[JSMflippedView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    
    [self.fileScrollView setDocumentView:fileDocumentView];
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}


- (IBAction)filePressed:(NSButton *)sender
{
    
    NSURL * openUrl =[Ldb.delegate getFileNameFromUser];
    
    if(openUrl == nil)
    {
        return;
    }
    
    [Ldb registerFile:openUrl];
    [self rebuildFileList];
}

-(void) deleteParentFile:(NSButton *)sender
{
    JSMFileView * f = (JSMFileView *)[sender superview];
    if(![f isKindOfClass:[JSMFileView class]])
    {
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Really Delete %@?", f.fileName.stringValue]];
    [alert setInformativeText:[NSString stringWithFormat:@"Are you sure you want to delete %@ ?", f.fileName.stringValue]];
    NSInteger response = [alert runModal];
    if(response == NSAlertFirstButtonReturn)
    {
        JSFiles * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
        [Ldb unregisterFileWithId:[fileInfo  objectID]];
        [self rebuildFileList];
    }
    else
    {
        return;
    }
}

-(void) changeCssFile:(NSButton *)sender
{
    JSMFileView * f = (JSMFileView *)[sender superview];
    if(![f isKindOfClass:[JSMFileView class]])
    {
        return;
    }
    
    NSURL * saveUrl = [Ldb.delegate getSaveNameFromUser];
    if(saveUrl == nil)
    {
        return;
    }
    JSFiles * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
   [Ldb updateMinifiedPath:saveUrl forJSFile:fileInfo];
    [self rebuildFileList];
}

-(void) advancedButtonPressed:(NSButton *)sender
{
    JSMFileView * f = (JSMFileView *)[sender superview];
    if(![f isKindOfClass:[JSMFileView class]])
    {
        return;
    }
    
    f.isAdvancedToggled = !f.isAdvancedToggled;
    [self scrollToPosition:NSMakePoint(0, f.frame.origin.y)];
    [self relayoutFileViews];
}

-(void) userUpdatedFilePreference:(NSButton *)sender
{
    JSMFileView * f = (JSMFileView *)[sender superview];
    while(![f isKindOfClass:[JSMFileView class]] && [f superview] != nil)
    {
        f = (JSMFileView *)[f superview];
    }
    
    if(![f isKindOfClass:[JSMFileView class]])
    {
        return;
    }
    
    JSFiles * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
    [Ldb updateFileOptions:[f getOptionValues] forFile:fileInfo];
    
    [Ldb updateParentFilesList];
    [self updateFileViewOptions];
}

-(void) rebuildFileList
{
    
    [Ldb updateParentFilesList];
    [fileDocumentView setSubviews:[NSArray array]];
    
    fileViews = [NSMutableArray array];
    
    // if there are no files to display, then display a footer.
    
    if(Ldb.currentParentFilesCount == 0)
    {
        [fileDocumentView setFrame:NSMakeRect(0, 0, 583, self.fileScrollView.frame.size.height - 10)];
        NSView * footerView = [Ldb.delegate getNibNamed:@"FileFooter" forClass:[NSView class]];
        
        NSRect fRect = footerView.frame;
        fRect.origin.y = 0;
        footerView.frame = fRect;
        
        [fileDocumentView addSubview:footerView];
        return;
    }
    
    //otherwise, display the list of files.
    
    for(int i = Ldb.currentParentFilesCount - 1; i >= 0; i--)
    {
        JSFiles * currentFile = [Ldb.currentParentFiles objectAtIndex:i];
        JSMFileView * f = [Ldb.delegate getNibNamed:@"FileView" forClass:[JSMFileView class]];
        
        if(f == nil)
        {
            
        }
        
        
        //setup actions and target for all the checkboxes
        [f setupOptionsWithSelector:@selector(userUpdatedFilePreference:) andTarget:self];
        
        // set the less and css paths
        NSURL * url = [NSURL fileURLWithPath:currentFile.path isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:currentFile.path];
        [f.cssPath setStringValue:currentFile.minified_path];
        
        
        //setup the rest of the non-preference button actions
        [f.deleteButton setAction:@selector(deleteParentFile:)];
        [f.deleteButton setTarget:self];
        [f.changeCssPathButton setAction:@selector(changeCssFile:)];
        [f.changeCssPathButton setTarget:self];
        [f.advancedButton setAction:@selector(advancedButtonPressed:)];
        [f.advancedButton setTarget:self];
        
        f.fileIndex = i;
        
        [fileViews addObject:f];
        [fileDocumentView addSubview:f];
    }
    [self updateFileViewOptions];
    [self relayoutFileViews];
}

-(void) updateFileViewOptions
{
    
    for(JSMFileView * f in fileViews)
    {
        JSFiles * currentFile = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
        
        //now populate the checkboxes with the user's current preferences
        NSData * optionsData = [currentFile.options dataUsingEncoding:NSUTF8StringEncoding];

        if(optionsData != nil && optionsData != (id)[NSNull null])
        {
            NSDictionary * options = [NSJSONSerialization JSONObjectWithData:optionsData options:0 error:nil];
            [f setCheckboxesForOptions:options];
        }
        
    }
}

-(void) relayoutFileViews
{
    float frameHeight = [self getHeightOfFileViews];

    [fileDocumentView setFrame:NSMakeRect(0, 0, 583, MAX(frameHeight, self.fileScrollView.frame.size.height - 10))];
    
    for(JSMFileView * f in fileViews)
    {
        if(f.fileIndex == 0)
        {
            f.horizontalLine.hidden = true;
        }
        else
        {
            f.horizontalLine.hidden = false;
        }
        float viewHeight = 70;
        float viewWidth = f.frame.size.width;
        if(f.isAdvancedToggled)
        {
            viewHeight = 315;
            f.advancedSettingsView.hidden = false;
        }
        else
        {
            f.advancedSettingsView.hidden = true;
        }
        
        float viewY = frameHeight - viewHeight;
        [f setFrame:NSMakeRect(0, viewY, viewWidth, viewHeight)];
        frameHeight -= viewHeight;
    }
    

	
}


-(float) getHeightOfFileViews
{
    float frameHeight = 0;
    for(JSMFileView * f in fileViews)
    {
        if(f.isAdvancedToggled)
        {
            frameHeight += 315;
        }
        else
        {
            frameHeight += 70;
        }
    }
    return frameHeight;
}


- (void)scrollToPosition:(NSPoint)p {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.37];
    NSClipView* clipView = [self.fileScrollView contentView];
    NSPoint newOrigin = [clipView bounds].origin;
    newOrigin.x = p.x;
    newOrigin.y = p.y;
    [[clipView animator] setBoundsOrigin:newOrigin];
    [self.fileScrollView reflectScrolledClipView: [self.fileScrollView contentView]];
    [NSAnimationContext endGrouping];
}

#pragma mark - DraggingDestinationDelegate


-(void) draggingDestinationPerformedDragOperation:(id<NSDraggingInfo>)sender
{
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([[pboard types] containsObject:NSURLPboardType]) {
        
        NSArray *paths = [pboard propertyListForType:NSURLPboardType];
        for(NSString * aPath in paths)
        {
            if([aPath isEqualToString:@""])
            {
                continue;
            }
            NSURL * aUrl = [NSURL URLWithString:aPath];
            
//            [Ldb performSelectorOnMainThread:@selector(registerFile:) withObject:aUrl waitUntilDone:true];
            [Ldb registerFile:aUrl];
        }
    }
    
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
    
}

@end
