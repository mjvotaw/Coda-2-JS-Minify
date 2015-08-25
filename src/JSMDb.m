//
//  JSMDb.h
//  JSMinify
//
//  Created by Michael on 10/26/14.
//
//

#import "JSMDb.h"

static JSMDb * sharedDb;

@implementation JSMDb

-(JSMDb *)initWithDelegate:(JSMBaseCodaPlugin<JSDbDelegate> *)d
{
    if(self = [super init])
    {
        self.delegate = d;
        sharedDb = self;
    }
    return self;
}

+(JSMDb *)SharedJSDb
{
    if(sharedDb == nil)
    {
        sharedDb = [[JSMDb alloc] init];
    }
    return sharedDb;
}

#pragma mark - database setup

-(void) setupDb
{
    //Create Db file if it doesn't exist
    [self persistentStoreCoordinator];
    [self reloadDbPreferences];
}


// Save a copy of db.sqlite into wherever NSHomeDirectory() points us

-(BOOL) copyFileNamed:(NSString *)name ofType:(NSString *)type
{
    NSError * error;
    if(![_delegate doesPersistantStorageDirectoryExist])
    {
        error = [_delegate createPersistantStorageDirectory];
        if(error)
        {
            [_delegate logError:[NSString stringWithFormat: @"JSMinify:: Error creating Persistant Storage Directory: %@", error] ];
            return false;
        }
    }
    NSString * path = [_delegate.pluginBundle pathForResource:name ofType:type];
    [_delegate logError:[NSString stringWithFormat: @"JSMinify:: path for resource: %@",path] ];
    error = [_delegate copyFileToPersistantStorage:path];
    if(error)
    {
        [_delegate logError:[NSString stringWithFormat: @"JSMinify:: Error creating file %@.%@: %@",name,type, error] ];
        return false;
    }
    [_delegate logError:[NSString stringWithFormat: @"JSMinify:: Successfully created file %@.%@", name, type] ];
    
    
    return true;
}

#pragma mark - general preferences


// retrieve the preferences from the database, and create an NSDictionary from them
-(JSMPreferences *) getDbPreferences
{
    NSArray * f = [self fetResultsForEntityNamed:@"Preferences"];
    if(f.count == 0)
    {
        JSMPreferences * p = [self newObjectForEntityForName:@"Preferences"];
        p.json = @"{\
        \"displayOnError\":1,\
        \"displayOnSuccess\":1,\
        \"openFileOnError\":0,\
        \"playOnSuccess\":0,\
        \"playOnError\":1\
    }";
        [[self managedObjectContext] save:nil];
        return p;
    }
    return f[0];
}


-(void) reloadDbPreferences
{
    
    _internalPreferences = [self getDbPreferences];
    _prefs = [[NSJSONSerialization JSONObjectWithData:[_internalPreferences.json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] mutableCopy];
    
    [self updateParentFilesListWithCompletion:nil];
}


// Update the given preference, and push the change to the database
-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val
{
    [_prefs setObject:val forKey:pref];
    [self setPreferences:_prefs];
}

// Take the given preferences and save them as a json object in the database
-(void) setPreferences:(NSDictionary *)preferences
{
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:preferences options:kNilOptions error:nil];
    NSString * preferenceString = [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding];
    [_internalPreferences setJson:preferenceString];
    [[self managedObjectContext] save:nil];
}

#pragma mark - file registration

// For a given url, determine if it is a file we should register (is it even a .js file? Is it a dependency of an existing registered file?).
// If so, save it to the database, and check if it has any dependencies that need to be tracked as well.

-(void) registerFile:(NSURL *)url
{
    [_delegate logMessage:[NSString stringWithFormat: @"JSMinify:: registering file: %@", url] ];
    if(url == nil)
    {
        return;
    }
    
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    if(![[fileName pathExtension] isEqualToString:@"js"])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Hey that file isn't a js file"];
        [alert setInformativeText:[NSString stringWithFormat:@"The file '%@' doesn't appear to be a js file.", [fileName lastPathComponent]]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[[_delegate.controller focusedTextView] window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        return;
    }
    
    NSString *cssFile = [fileName stringByReplacingOccurrencesOfString:[url lastPathComponent] withString:[[url lastPathComponent] stringByReplacingOccurrencesOfString:@".js" withString:@".min.js"]];
    
    
    NSArray * existingFiles = [self fetchResultsForEntityNamed:@"JSFiles" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@", fileName]];
    JSFiles * newFile;
    if(existingFiles.count == 0)
    {
        newFile = [self newObjectForEntityForName:@"JSFiles"];
    }
    else
    {
        newFile = existingFiles[0];
    }
    
    newFile.minified_path = cssFile;
    newFile.path = fileName;
    newFile.site_uuid = [_delegate getCurrentSiteUUID];
    NSError * error;
    [_managedObjectContext save:&error];
}

-(void) unregisterFileWithId:(NSManagedObjectID*)fileId
{
    [[self managedObjectContext] deleteObject: [[self managedObjectContext] objectWithID:fileId]];
    [[self managedObjectContext] save:nil];
}

-(JSFiles *)JSFileForFilePath:(NSString *)filePath
{
    NSString * fileName = [_delegate getResolvedPathForPath:filePath];
    NSArray * files = [self fetchResultsForEntityNamed:@"JSFiles" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@", fileName]];
    if(files.count == 0)
    {
        return nil;
    }
    return files[0];
}

# pragma mark - other things

// Make sure our local copy of _currentParentFiles is up to date.


-(void) updateParentFilesList
{
    
    NSArray * parentFiles = [self fetchResultsForEntityNamed:@"JSFiles" WithPredicate:[NSPredicate predicateWithFormat:@"parent == nil"]];
    _currentParentFiles = [parentFiles mutableCopy];
    _currentParentFilesCount = _currentParentFiles.count;
}

-(void) updateParentFilesListWithCompletion:(void(^)(void))handler;
{
    if([_delegate getCurrentSiteUUID] == nil)
    {
        return;
    }
    
    [self updateParentFilesList];
    if(handler)
    {
        handler();
        return;
    }
}

// If the user chooses to update the css path of a js file to somewhere else.

-(void) updateMinifiedPath:(NSURL *)minifiedUrl forJSFile: (JSFiles *)jsFile
{
    NSString * minifiedPath = [_delegate getResolvedPathForPath:[minifiedUrl path]];
    [jsFile setMinified_path:minifiedPath];
    [[self managedObjectContext] save:nil];
}

// Update preferences specific to each js file.

-(void) updateFileOptions:(NSDictionary *)options forFile:( JSFiles *)jsFile
{
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:options options:kNilOptions error:nil];
    NSString * preferenceString = [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding];
    [jsFile setOptions:preferenceString];
    [[self managedObjectContext] save:nil];
}

#pragma mark - coredata

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[_delegate bundle] URLForResource:@"Model" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }

    if(![_delegate doesPersistantStorageDirectoryExist])
    {
        [_delegate createPersistantStorageDirectory];
    }
    NSURL *storeURL = [_delegate urlForPeristantFilePath:@"db_core_data.sqlite"];
    NSError *error = nil;

    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:@{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES} error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


#pragma mark - core data helpers

-(NSArray *) fetchResultsForEntityNamed:(NSString *)entityName WithPredicate:(NSPredicate *)predicate AndSortDescriptors:(NSArray *)sortDescriptors
{
    NSFetchRequest * fetch = [[NSFetchRequest alloc] init];
    [fetch setEntity: [_managedObjectModel entitiesByName ][entityName] ];
    [fetch setPredicate: predicate];
    [fetch setSortDescriptors: sortDescriptors];
    
    NSArray * results = [[self managedObjectContext] executeFetchRequest:fetch error:nil];
    return results;
}

-(NSArray *)fetchResultsForEntityNamed:(NSString *)entityName WithPredicate:(NSPredicate *)predicate
{
    return [self fetchResultsForEntityNamed:entityName WithPredicate:predicate AndSortDescriptors:nil];
}

-(NSArray *)fetResultsForEntityNamed:(NSString *)entityName
{
    return [self fetchResultsForEntityNamed:entityName WithPredicate:nil AndSortDescriptors:nil];
}

-(id)newObjectForEntityForName:(NSString *)entityName
{
    return [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:[self managedObjectContext]];
}


@end
