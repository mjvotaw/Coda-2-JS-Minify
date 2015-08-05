#import "JSMBaseCodaPlugin.h"
#import "DDLog.h"
#import "DDASLLogger.h"

static int ddLogLevel = LOG_LEVEL_ERROR;

@interface JSMBaseCodaPlugin ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation JSMBaseCodaPlugin

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
    if ( (self = [super init]) != nil )
	{
		_controller = inController;
	}
    _pluginBundle = p;
    _bundle = [NSBundle bundleWithIdentifier:[p bundleIdentifier]];
    currentSiteUUID = @"*";
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		_controller = inController;
	}
	return self;
}


-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return true;
}


#pragma mark - Site methods

- (void)didLoadSiteNamed:(NSString*)name
{
    
    currentSiteUUID = [self getCurrentSiteUUID];
    
    if(currentSiteUUID == nil)
    {
        currentSiteUUID = @"*";
    }
}

#pragma mark - Menu methods

-(NSURL *) getFileNameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    NSString * openTo = [self getSiteLocalPath];
    if(openTo == nil || [openTo isEqualToString:@""])
    {
        openTo = NSHomeDirectory();
    }
    [openDlg setDirectoryURL: [NSURL fileURLWithPath:openTo]];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    
    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];
    
    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];
    
    // Display the dialog. If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [openDlg URLs];
        
        // Loop through all the files and process them.
        for(NSURL * url in files)
        {
            chosenFile = url;
        }
    }
    return chosenFile;
}

-(NSURL *) getSaveNameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSString * openTo = [self getSiteLocalPath];
    if(openTo == nil || [openTo isEqualToString:@""])
    {
        openTo = NSHomeDirectory();
    }
    [saveDlg setDirectoryURL: [NSURL fileURLWithPath:openTo]];
    [saveDlg setCanCreateDirectories:TRUE];
    
    if ( [saveDlg runModal] == NSOKButton )
    {
        chosenFile = [saveDlg URL];
    }
    return chosenFile;
}


#pragma mark - persistant storage methods
/* these methods can be used to store files in NSHomeDirectory(), to protect these files from being deleted when plugins/Coda are updated. 
 */

-(BOOL) doesPersistantFileExist:(NSString *)path
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
	NSURL * url = [self urlForPeristantFilePath:path];
    return  [fileManager fileExistsAtPath:[url path]];
}

-(BOOL) doesPersistantStorageDirectoryExist
{
    return [self doesPersistantFileExist:@""];
}

-(NSURL *) urlForPeristantFilePath:(NSString *)path
{
    NSURL * url = [NSURL fileURLWithPath:NSHomeDirectory()];
    url = [url URLByAppendingPathComponent:[NSString stringWithFormat:@".%@/%@", [self name], path]];
    return url;
}

-(NSError *) createPersistantStorageDirectory
{
    NSError * error;
    NSURL * url = [self urlForPeristantFilePath:@""];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtURL:url withIntermediateDirectories:NO attributes:nil error:&error];
    return error;
}

-(NSError *) copyFileToPersistantStorage:(NSString *)path
{
    NSError * error = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString * filename = [path lastPathComponent];
    NSURL * url = [self urlForPeristantFilePath: filename];
    if(![self doesPersistantStorageDirectoryExist])
    {
        error = [self createPersistantStorageDirectory];
        if(error != nil)
        {
            return error;
        }
    }
    if([self doesPersistantFileExist:filename])
    {
        [fileManager moveItemAtPath:[url path] toPath:[[self urlForPeristantFilePath:[NSString stringWithFormat:@"%@.%ld", filename, time(nil)]] path] error:&error];
        if(error != nil)
        {
            return error;
        }
    }
    
    [fileManager copyItemAtPath:path toPath: [url path] error:&error];
    return error;
}


#pragma mark - url/path helper methods


-(NSString *) getResolvedPathForPath:(NSString *)path
{
    NSURL * url = [NSURL fileURLWithPath:path];
    url = [NSURL URLWithString:[url absoluteString]];	//absoluteString returns path in file:// format
	NSString * newPath = [[url URLByResolvingSymlinksInPath] path];	//URLByResolvingSymlinksInPath expects file:// format for link, then resolves all symlinks
    return newPath;
}

#pragma mark - NSUserNotification
-(void) sendUserNotificationWithTitle:(NSString *)title andMessage:(NSString *)message
{
    if(NSClassFromString(@"NSUserNotification"))
    {
		[self sendUserNotificationWithTitle:title sound:nil andMessage:message];
    }
    else
    {
    	[GrowlApplicationBridge notifyWithTitle:title description:message notificationName:@"GrowlCompleteUpload" iconData:nil priority:0 isSticky:false clickContext:nil];
    }
}

-(void) sendUserNotificationWithTitle:(NSString *)title sound:(NSString *)sound andMessage:(NSString * ) message
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    notification.soundName = sound;
    
	if([[NSUserNotificationCenter defaultUserNotificationCenter] delegate] == nil)
    {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}


#pragma mark - Growl delegate

-(NSDictionary *)registrationDictionaryForGrowl
{
    NSDictionary * dictionary = @{GROWL_APP_NAME: @"Coda 2", GROWL_NOTIFICATIONS_ALL: @[@"CodaPluginNotification"], GROWL_NOTIFICATIONS_DEFAULT: @[@"CodaPluginNotification"]};
    
    return dictionary;
}

#pragma mark - OS X compatability methods

-(id) getNibNamed:(NSString *)nibName forClass:(Class)nibClass
{
    NSArray * nibObjects = [self loadNibNamed:nibName];
    for(id o in nibObjects)
    {
        if([o isKindOfClass:[NSApplication class]])
        {
            continue;
        }
        else
        {
            return o;
        }
    }
    return nil;
}

-(NSArray *) loadNibNamed:(NSString *)nibName
{
    DDLogVerbose(@"JSMinify:: loading nib: %@", nibName);
    NSMutableArray * nibObjects = [NSMutableArray array];
    if([_bundle respondsToSelector:@selector(loadNibNamed:owner:topLevelObjects:)])
    {

        [_bundle loadNibNamed:nibName owner:self topLevelObjects:&nibObjects];
    }
    else if([_bundle respondsToSelector:@selector(loadNibFile:externalNameTable:withZone:)])
    {
		NSDictionary * nameTable = @{NSNibOwner:self, NSNibTopLevelObjects: nibObjects};
        [_bundle loadNibFile:nibName externalNameTable:nameTable withZone:nil];
    }
    
    return nibObjects;
}


#pragma mark - other helpers

-(BOOL) isSiteOpen
{
    BOOL isSiteOpen = false;
    if([_controller respondsToSelector:@selector(siteUUID)])
    {
        isSiteOpen = [_controller siteUUID] != nil;
    }
	else if([_controller respondsToSelector:@selector(focusedTextView:)])
    {
        isSiteOpen = [_controller focusedTextView:nil] != nil && [[_controller focusedTextView:nil] siteNickname] != nil;
    }
    
    return isSiteOpen;
}

-(NSString *) getCurrentSiteUUID
{
    if([_controller respondsToSelector:@selector(siteUUID)])
    {
        return [_controller siteUUID];
    }
	else if([_controller respondsToSelector:@selector(focusedTextView:)] && [_controller focusedTextView:nil] != nil)
    {
        return [[_controller focusedTextView:nil] siteNickname];
    }
    
	return nil;
}
-(NSString *) updateCurrentSiteUUID;
{
    //if siteUUID is not available, that means that this is Coda 2.0
    //so we have to make sure that the currentSiteUUID is set to at least something
    currentSiteUUID = [self getCurrentSiteUUID];
    if(currentSiteUUID == nil)
    {
        currentSiteUUID = @"*";
    }
    
    return currentSiteUUID;
}

-(NSString *) getSiteLocalPath
{
    if([_controller respondsToSelector:@selector(siteLocalPath)])   //Coda 2.5
    {
       return [_controller siteLocalPath];
    }
    else if([_controller respondsToSelector:@selector(focusedTextView:)] && [_controller focusedTextView:nil] != nil) //Coda 2
    {
        [[_controller focusedTextView:nil] siteLocalPath];
    }

    return nil;
}

@end
