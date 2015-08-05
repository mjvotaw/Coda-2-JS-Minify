#import "JSPlugin.h"
#import "CodaPlugInsController.h"
#import "FileView.h"

@interface JSPlugin ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation JSPlugin

//2.0 and lower
- (id)initWithPlugInController:(CodaPlugInsController*)aController bundle:(NSBundle*)aBundle
{
    return [self initWithController:aController];
}


//2.0.1 and higher
- (id)initWithPlugInController:(CodaPlugInsController*)aController plugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    return [self initWithController:aController andPlugInBundle:p];
}

- (id)initWithController:(CodaPlugInsController*)inController andPlugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    if ( (self = [super initWithController:inController andPlugInBundle:p]) != nil )
	{
        [self registerActions];
        Ldb = [[JSMDb alloc] initWithDelegate:self];
        [Ldb setupDb];
    }
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		self.controller = inController;
        [self registerActions];
    }
	return self;
}

-(void) registerActions
{
    [self.controller registerActionWithTitle:@"Site Settings" underSubmenuWithTitle:nil target:self selector:@selector(openSitesMenu) representedObject:nil keyEquivalent:nil pluginName:@"JS Minify"];
    
    [self.controller registerActionWithTitle:@"Preferences" underSubmenuWithTitle:nil target:self selector:@selector(openPreferencesMenu) representedObject:nil keyEquivalent:nil pluginName:@"JS Minify"];
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    //preference menu can always be opened.
    if([[menuItem title] isEqualToString:@"Preferences"])
    {
        return true;
    }
    
    return [self isSiteOpen];
}

- (NSString*)name
{
	return @"JS Minify";
}

-(void)textViewWillSave:(CodaTextView *)textView
{
    NSString *path = [textView path];
    if([path length] > 0)
    {
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        if([[url pathExtension] isEqualToString:@"js"])
        {
            [self performSelector:@selector(handleJSFile:) withObject:[self getResolvedPathForPath:path] afterDelay:0.01];
//            [self performSelectorOnMainThread:@selector(handleLessFile:) withObject:textView waitUntilDone:true];
        }
    }
}

#pragma mark - Menu methods

-(void) openSitesMenu
{
    if(siteSettingsController != nil)
    {
        [siteSettingsController showWindow:self];
        return;
    }
    
    [self updateCurrentSiteUUID];
    siteSettingsController = [[JSMsiteSettingsWindowController alloc] init];
    [siteSettingsController showWindow:self];
}

-(void) openPreferencesMenu
{
    if(preferenceController != nil)
    {
        [preferenceController showWindow:self];
        return;
    }
    
    preferenceController = [[JSMpreferenceWindowController alloc] init];
    [preferenceController showWindow:self];
}

#pragma mark - NSWindowDelegate methods


-(void)windowWillClose:(NSNotification *)notification
{
    if([[notification object] isEqualTo:siteSettingsController.window])
    {
        siteSettingsController = nil;
    }
    
    if([[notification object] isEqualTo:preferenceController.window ])
    {
        preferenceController = nil;
    }
}


#pragma mark - LESS methods

-(void) handleJSFile:(NSString *)path
{
    if(isCompiling || (task!= nil && [task isRunning]))
    {
        
        return;
    }
    
    
    
    
    
    JSFiles * parent = [Ldb JSFileForFilePath:path];
    if(parent == nil)
    {
        return;
    }
    NSString * parentPath = parent.path;
    NSString * cssPath = parent.minified_path;
    
    
    
    
    
    //Set compilation options
    NSMutableArray * options  = [NSMutableArray array];
    NSData * optionsData = [parent.options dataUsingEncoding:NSUTF8StringEncoding];
    
    if(optionsData != nil && ![optionsData isEqual:[NSNull null]])
    {
        NSDictionary * parentFileOptions = [NSJSONSerialization JSONObjectWithData:optionsData options:0 error:nil];
        if(parentFileOptions != nil && parentFileOptions != (id)[NSNull null])
        {
            for(NSString * optionName in parentFileOptions.allKeys)
            {
                if([[parentFileOptions objectForKey:optionName] intValue] == 1)
                {
                    [options addObject:optionName];
                }
            }
        }
    }
    
    
    int resultCode = [self compileFile:parentPath toFile:cssPath withOptions:options];
}

-(int) compileFile:(NSString *)lessFile toFile:(NSString *)cssFile withOptions:(NSArray *)options
{
    if(isCompiling || (task!= nil && [task isRunning]))
    {
        
        return -1;
    }
    isCompiling = true;
    compileCount++;
    
    

    NSString * launchPath = [NSString stringWithFormat:@"%@/node", [self.pluginBundle resourcePath]];
    NSString * lessc = [NSString stringWithFormat:@"%@/uglify/bin/uglifyjs", [self.pluginBundle resourcePath]];
    NSMutableArray * arguments = [NSMutableArray array];
    [arguments addObject:lessc];
    [arguments addObject:lessFile];
    
    if(options)
    {
        for(NSString * arg in options)
        {
            NSArray * argPieces = [arg componentsSeparatedByString:@" "];
            [arguments addObjectsFromArray:argPieces];
        }
    }
    

    [arguments addObject:@"--output"];
    [arguments addObject:cssFile];
    
    
    
    
    task = [[JSMTaskMan alloc] initWithLaunchPath:launchPath AndArguments:arguments];
    [task launch];
    outputText = [task getOutput];
    errorText = [task getError];
    int resultCode = [task resultCode];
    
    
    
    if(resultCode == 0)
    {
        [self displaySuccess];
    }
    else
    {
        [self displayError:errorText];
    }

    isCompiling = false;
    task = nil;
    return resultCode;
}

/* parse the error message and pull the useful bits from it. */

-(NSDictionary *) getErrorMessage:(NSString *)fullError
{
    NSError * error = nil;
    NSDictionary * output = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Parse error at (.*?):(\\d*),(\\d*)\\n(.*?)\\nError" options:nil error:&error];
//    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.*?)Error:(.*?) in (.*?less) on line (.*?), column (.*?):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        NSString * filePath = 	  [fullError substringWithRange:[ntcr rangeAtIndex:1]];
        NSString * fileName = [filePath lastPathComponent];
        
        NSString * lineNumber = 	  [fullError substringWithRange:[ntcr rangeAtIndex:2]];
        NSString * columnNumber = 	  [fullError substringWithRange:[ntcr rangeAtIndex:3]];
        NSString * error = 	  [fullError substringWithRange:[ntcr rangeAtIndex:4]];
        
        NSString * errorMessage = [NSString stringWithFormat:@"Error in %@, at %@,%@:\n%@", fileName, lineNumber, columnNumber, error];
        
        output = @{@"errorMessage": errorMessage,
                   @"errorType": error,
                   @"filePath": filePath,
                   @"fileName": fileName,
                   @"lineNumber":lineNumber,
                   @"columnNumber":columnNumber};
        
    }
    return output;
}

-(NSString *) getFileNameFromError:(NSString *)fullError
{
    NSError * error = nil;
    NSString * output = [NSString stringWithFormat:@""];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ParseError:(.*?) in (.*?less) (.*):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        output = [fullError substringWithRange:[ntcr rangeAtIndex:2]];
    }
    return output;
}



-(void) displaySuccess
{
    if([[Ldb.prefs objectForKey:@"displayOnSuccess"] intValue] == 1)
    {
        NSString * sound = nil;
        if([[Ldb.prefs objectForKey:@"playOnSuccess"] intValue] == 1)
        {
            sound = NSUserNotificationDefaultSoundName;
        }
        
        [self sendUserNotificationWithTitle:@"JSMinify:: Compiled Successfully!" andMessage:@"file compiled successfully!"];
    }
}

-(void) displayError:(NSString *)errorText
{
    NSDictionary * error = [self getErrorMessage:errorText];
    if(error != nil)
    {
        if([[Ldb.prefs objectForKey:@"displayOnError"] integerValue] == 1)
        {
            NSString * sound = nil;
            if([[Ldb.prefs objectForKey:@"playOnError"] integerValue] == 1)
            {
                sound = @"Basso";
            }
            
            [self sendUserNotificationWithTitle:@"JSMinify:: Parse Error" andMessage:[error objectForKey:@"errorMessage"]];
        }
        
        if([[Ldb.prefs objectForKey:@"openFileOnError"] integerValue] == 1)
        {
            NSError * err;
            CodaTextView * errorTextView = [self.controller openFileAtPath:[error objectForKey:@"filePath"] error:&err];
            if(err)
            {
                
                return;
            }
            
            [errorTextView goToLine:[[error objectForKey:@"lineNumber"] integerValue] column:[[error objectForKey:@"columnNumber"] integerValue] ];
        }
    }

}
@end
