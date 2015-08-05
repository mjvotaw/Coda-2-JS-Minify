//
//  LessDb.m
//  LESSCompile
//
//  Created by Michael on 10/26/14.
//
//

#import "JSMDb.h"
#import "DDLog.h"
#import "DDASLLogger.h"

#define DBERROR(frmt, ...) [sharedDb errorToDatabase:frmt, ##__VA_ARGS__];
static int ddLogLevel;
static float COMPATIBLEDB = 0.6;
static float VERY_OLD_DB = 0.4;
static JSMDb * sharedDb;

@implementation JSMDb

-(JSMDb *)initWithDelegate:(JSMBaseCodaPlugin<LessDbDelegate> *)d
{
    if(self = [super init])
    {
        self.delegate = d;
        sharedDb = self;
    }
    return self;
}

+(JSMDb *)sharedLessDb
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
    
    NSURL * dbFile;
    if (![_delegate doesPersistantFileExist:@"db.sqlite"]) {
        DDLogError(@"JSMinify:: db file does not exist. Attempting to create.");
        if(![self copyFileNamed:@"db" ofType:@"sqlite"])
        {
            return;
        }
    }
    dbFile = [_delegate urlForPeristantFilePath:@"db.sqlite"];
    DDLogError(@"JSMinify:: dbFile: %@", dbFile);
    
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * versionSet  = [db executeQuery:@"SELECT version from preferences"];
        if([versionSet next])
        {
            float dbVersion = [versionSet doubleForColumn:@"version"];
            [versionSet close];
            //The current database version is lower than the latest, so we'll need to kill it :x
            if(dbVersion < COMPATIBLEDB)
            {
                [self performSelectorOnMainThread:@selector(replaceDatabase:) withObject:@(dbVersion) waitUntilDone:false];
            }
            else
            {
                [self performSelectorOnMainThread:@selector(reloadDbPreferences) withObject:nil waitUntilDone:false];
            }
        }
        [versionSet close];
    }];
    
    [self updateParentFilesListWithCompletion:nil];
}


-(void) setupLog
{
    NSURL * logFile;
    if (![_delegate doesPersistantFileExist:@"log.sqlite"]) {
        DDLogError(@"JSMinify:: log file does not exist. Attempting to create.");
        if(![self copyFileNamed:@"log" ofType:@"sqlite"])
        {
            return;
        }
    }
    logFile = [_delegate urlForPeristantFilePath:@"log.sqlite"];
    DDLogError(@"JSMinify:: dbFile: %@", logFile);
    
    _dbLog = [FMDatabaseQueue databaseQueueWithPath:[logFile path]];
}

-(void) replaceDatabase:(NSNumber *)currentDbVersion
{
    DDLogError(@"JSMinify:: Current database incompatible with latest compiler release. Attempting to migrate.");
    NSURL * dbFile;
    
    if(currentDbVersion.floatValue < VERY_OLD_DB)	// if we're updating from a very old version, just nuke the database.
    {
        DDLogError(@"JSMinify:: very old version, sorry we're just nuking everything.");
        if(![self copyFileNamed:@"db" ofType:@"sqlite"])
        {
            return;
        }
        
        dbFile = [_delegate urlForPeristantFilePath:@"db.sqlite"];
        DDLogError(@"JSMinify:: dbFile: %@", dbFile);
        
        [_dbQueue close];
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
        [self reloadDbPreferences];
        return;
    }
    
    //Otherwise, we're on a new enough copy that we can try to maintain most of the content
    
    //try to maintain as much of what the person setup as we can
    NSArray * parentFiles = [self getParentFiles];
    NSDictionary * preferences = [self getDbPreferences];
    
    if(![self copyFileNamed:@"db" ofType:@"sqlite"])
    {
        return;
    }
    
    dbFile = [_delegate urlForPeristantFilePath:@"db.sqlite"];
    DDLogError(@"JSMinify:: dbFile: %@", dbFile);
    
    [_dbQueue close];
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    
    //re-register previously registered files
    
    for(NSDictionary * file in parentFiles)
    {
        DDLogError(@"JSMinify:: re-registering file '%@'", [file objectForKey:@"path"]);
        
        [_dbQueue inDatabase:^(FMDatabase *db) {
            
        	if(![db executeUpdate:@"INSERT OR REPLACE INTO js_files (minified_path, path, parent_id, site_uuid) VALUES (:minified_path, :path, :parent_id, :site_uuid)"
          withParameterDictionary:file ])
            {
                DDLogError(@"JSMinify:: SQL ERROR: %@", [db lastError]);
                return;
            }
            DDLogError(@"JSMinify:: Inserted registered file");
            
        }];
//        [self addDependencyCheckOnFile:[file objectForKey:@"path"]];
    }
    
    //set preferences back
    [self setPreferences:preferences];
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
            DDLogError(@"JSMinify:: Error creating Persistant Storage Directory: %@", error);
            return false;
        }
    }
    NSString * path = [_delegate.pluginBundle pathForResource:name ofType:type];
    DDLogError(@"JSMinify:: path for resource: %@",path);
    error = [_delegate copyFileToPersistantStorage:path];
    if(error)
    {
        DDLogError(@"JSMinify:: Error creating file %@.%@: %@",name,type, error);
        return false;
    }
    DDLogError(@"JSMinify:: Successfully created file %@.%@", name, type);
    
    
    return true;
}

// This is intended to be used only when updating the database file. It pulls specific values that are common to previous versions of the database,
// So we can restore these values when db.sqlite is replaced.
-(NSArray *) getParentFiles;
{
    NSMutableArray * parentPaths = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * files = [db executeQuery:@"SELECT * FROM js_files WHERE parent_id = :parent_id" withParameterDictionary:@{@"parent_id" : @(-1)}];
        while([files next])
        {
            NSMutableDictionary * fields = [@{@"path": [files stringForColumn:@"path"],
                                              @"site_uuid": [files stringForColumn:@"site_uuid"],
                                              @"minified_path": [files stringForColumn:@"minified_path"],
                                              @"parent_id": @([files intForColumn:@"parent_id"])} mutableCopy];
            if([files stringForColumn:@"options"] != nil)
            {
                fields[@"options"] = [files stringForColumn:@"options"];
            }
            
            [parentPaths addObject: fields];
        }
    }];
    return parentPaths;
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
//    
//    __block NSDictionary * preferences;
//    [_dbQueue inDatabase:^(FMDatabase *db) {
//        FMResultSet * prefSet = [db executeQuery:@"SELECT * FROM preferences"];
//        if([prefSet next])
//        {
//            preferences = [[NSJSONSerialization JSONObjectWithData:[[prefSet stringForColumn:@"json"] dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] mutableCopy];
//            DDLogError(@"JSMinify:: prefs: %@", _prefs);
//        }
//        else
//        {
//            DDLogError(@"JSMinify:: no preferences found!");
//            preferences = [NSMutableDictionary dictionaryWithObjectsAndKeys: nil];
//        }
//        [prefSet close];
//    }];
//    
//    return preferences;
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
//    
//    [_dbQueue inDatabase:^(FMDatabase *db) {
//        
//        NSData * jData = [NSJSONSerialization dataWithJSONObject:preferences options:kNilOptions error:nil];
//        [db executeUpdate:@"UPDATE preferences SET json = :json WHERE id == 1" withParameterDictionary:@{@"json" : jData}];
//    }];
}

#pragma mark - file registration

// For a given url, determine if it is a file we should register (is it even a .less file? Is it a dependency of an existing registered file?).
// If so, save it to the database, and check if it has any dependencies that need to be tracked as well.

-(void) registerFile:(NSURL *)url
{
    DDLogVerbose(@"JSMinify:: registering file: %@", url);
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
    NSLog(@"JSFiles: %@", [self fetResultsForEntityNamed:@"JSFiles"]);
    NSLog(@"managedObjectContext Error: %@", error);
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        DBERROR(@"JSMinify:: registerFile");
        
        // check if the file has already been registered
        FMResultSet * file = [db executeQuery:@"SELECT * FROM js_files WHERE path = :path" withParameterDictionary:@{@"path": fileName}];
        if([file next])
        {
            // is it a dependency of a parent file?
            if([file intForColumn:@"parent_id"] > -1)
            {
                NSString * filePath = [[file stringForColumn:@"path"] lastPathComponent];
                FMResultSet * parent = [db executeQuery:@"SELECT * FROM js_files WHERE id = :id" withParameterDictionary:@{@"id" : [NSNumber numberWithInt:[file intForColumn:@"parent_id"]] }];
                
                //make sure that the parent file actually exists. If it does, then throw an alert.
                if([parent next])
                {
                    NSString * parentPath = [[parent stringForColumn:@"path"] lastPathComponent];
                    
                    DBERROR(@"JSMinify:: Trying to register dependency of file '%@'.", [parent stringForColumn:@"path"]);
                    
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:@"OK"];
                    [alert setMessageText:@"File already registered"];
                    [alert setInformativeText:[NSString stringWithFormat:@"The file '%@' is already a dependency of '%@'", filePath, parentPath]];
                    [alert setAlertStyle:NSWarningAlertStyle];
                    
                    [alert beginSheetModalForWindow:[[_delegate.controller focusedTextView] window] modalDelegate:self didEndSelector:nil contextInfo:nil];
                    [parent close];
                    [file close];
                    return;
                }
                [parent close];
            }
            //otherwise, we could maybe throw another alert here. But instead, let's just re-register the file.
        }
        [file close];
        
        NSDictionary * args = @{@"minified_path" : cssFile, @"path" : fileName, @"parent_id" : @(-1), @"site_uuid" : [_delegate getCurrentSiteUUID]};
        
        if(![db executeUpdate:@"INSERT OR REPLACE INTO js_files (minified_path, path, parent_id, site_uuid) VALUES (:minified_path, :path, :parent_id, :site_uuid)"
      withParameterDictionary:args ])
        {
            DBERROR(@"JSMinify:: SQL ERROR: %@", [db lastError]);
            return;
        }
        DDLogVerbose(@"JSMinify:: Inserted registered file");
//        [self performSelectorOnMainThread:@selector(addDependencyCheckOnFile:) withObject:fileName waitUntilDone:FALSE];
    }];
}


// Delete any references to the given url and its dependencies.
-(void) unregisterFile:(NSURL *)url
{
    
    NSArray * files = [self fetchResultsForEntityNamed:@"JSFiles" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@", url]];
    for(JSFiles * file in files)
    {
        [[self managedObjectContext] deleteObject:file];
    }
    
    [[self managedObjectContext] save:nil];
    
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * parentFile = [db executeQuery:@"SELECT * FROM js_files WHERE path == :path" withParameterDictionary:@{@"path":fileName}];
        if(![parentFile next])
        {
            DBERROR(@"JSMinify:: unregisterFile: file %@ not found in db", fileName);
            return;
        }
        
        int parentFileId = [parentFile intForColumn:@"id"];
        [db executeUpdate:@"DELETE FROM js_files WHERE parent_id == :parent_id" withParameterDictionary:@{@"parent_id" : [NSNumber numberWithInt:parentFileId]}];
        
        [db executeUpdate:@"DELETE FROM js_files WHERE id == :id" withParameterDictionary:@{@"id" : [NSNumber numberWithInt:parentFileId]}];
        DDLogVerbose(@"JSMinify:: unregisterFile: unregistered file %@", fileName);
        [parentFile close];
    }];
}

-(void) unregisterFileWithId:(NSManagedObjectID*)fileId
{
    [[self managedObjectContext] deleteObject: [[self managedObjectContext] objectWithID:fileId]];
    [[self managedObjectContext] save:nil];
//    
//    [_dbQueue inDatabase:^(FMDatabase *db) {
//        DDLogVerbose(@"JSMinify:: unregisterFile: unregistered file with id %d", fileId);
//
//        [db executeUpdate:@"DELETE FROM js_files WHERE parent_id = :parent_id" withParameterDictionary:@{@"parent_id" : @(fileId)}];
//        
//        BOOL worked = [db executeUpdate:@"DELETE FROM js_files WHERE id = :id" withParameterDictionary:@{@"id" : @(fileId)}];
//        NSLog(@"worked? %d", worked);
//    }];
}

#pragma  mark - depenencyCheck queue
/* To avoid calling multiple dependency checks at once, let's make a simple queue to process them in order. */

-(void) addDependencyCheckOnFile:(NSString *) path
{
    DDLogVerbose(@"JSMinify:: Adding path to dependencyQueue: %@", path);
    if(dependencyQueue == nil)
    {
        dependencyQueue = [NSMutableArray array];
    }
    
    @synchronized(dependencyQueue)
    {
        [dependencyQueue addObject:path];
        if(indexTask == nil || indexTask.isRunning == false)
        {
            [self runDependencyQueue];
        }
    }
}

-(void) runDependencyQueue
{
    DDLogVerbose(@"JSMinify:: runDependencyQueue");
    @synchronized(dependencyQueue)
    {
        if(dependencyQueue.count == 0)
        {
            DDLogVerbose(@"JSMinify:: queue is empty!");
            return;
        }
        NSString * path = [dependencyQueue firstObject];
        [dependencyQueue removeObjectAtIndex:0];
        [self performDependencyCheckOnFile:path];
    }
}

// Setup an NSTask to run the less compiler, parse the output to get the list of all dependency files,
// and register them as dependencies.

-(void) performDependencyCheckOnFile:(NSString *)path
{
    if(_isDepenencying)
    {
        DDLogVerbose(@"JSMinify:: Already checking Dependencies!");
        return;
    }
    DDLogVerbose(@"JSMinify:: Performing dependency check on %@", path);
    _isDepenencying = true;
    
    dependsPath = [_delegate getResolvedPathForPath:[[_delegate urlForPeristantFilePath:@"DEPENDS"] path]];
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet * parent = [db executeQuery:@"SELECT * FROM js_files WHERE path = :path" withParameterDictionary:@{@"path":path}];
        if(![parent next])
        {
            DBERROR(@"JSMinify:: Parent file not found in db!");
            [parent close];
            return;
        }
        
        int indexCurrentParentId = [parent intForColumn:@"id"];
        NSString * indexCurrentSiteUUID = [parent stringForColumn:@"site_uuid"];
        [parent close];

        //run less to get dependencies list
        NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [_delegate.pluginBundle resourcePath]];
        NSString * launchPath = [NSString stringWithFormat:@"%@/node", [_delegate.pluginBundle resourcePath]];
        tm = [[JSMTaskMan alloc] initWithLaunchPath:launchPath AndArguments:@[lessc, @"--depends", path, dependsPath]];
        [tm launch];
        NSString * output = [tm getOutput];
        NSArray * dependencies = [self parseDependencies:output];
        
        //Add or update the dependencies
        for(NSString * fileName in dependencies)
        {
            NSDictionary * args = @{@"minified_path" : @"", @"path" : fileName, @"parent_id" : @(indexCurrentParentId), @"site_uuid" : indexCurrentSiteUUID};
            if([db executeUpdate:@"INSERT OR REPLACE INTO js_files (minified_path, path, parent_id, site_uuid) VALUES (:minified_path, :path, :parent_id, :site_uuid)" withParameterDictionary:args])
            {
                DDLogVerbose(@"JSMinify:: dependency update succeeded: %@", fileName);
            }
            else
            {
                DBERROR(@"JSMinify:: dependency update failed: %@", fileName);
            }
        }
        
        //nuke anything that's not a current dependency
        
        NSString * dependenciesList = [NSString stringWithFormat:@"'%@'",[dependencies componentsJoinedByString:@"', '"]];
        [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM js_files WHERE parent_id = :parent_id AND path NOT IN (%@)", dependenciesList] withParameterDictionary:@{@"parent_id" : @(indexCurrentParentId)}];
        
    }];
    _isDepenencying = false;
    [self performSelectorOnMainThread:@selector(runDependencyQueue) withObject:nil waitUntilDone:false];
}


-(NSArray *) parseDependencies:(NSString *)outStr
{
    NSMutableArray * depencyList = [NSMutableArray array];
                  
    outStr = [outStr stringByReplacingOccurrencesOfString:dependsPath withString:@""];
    NSError * error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(/.*?\\.less)" options:nil error:&error];
    if(error != nil)
    {
        DBERROR(@"JSMinify:: error with regex: %@", error);
    }
    NSArray * dependencies = [regex matchesInString:outStr options:nil range:NSMakeRange(0, [outStr length])];
    if([dependencies count] > 0)
    {
        for(NSTextCheckingResult * ntcr in dependencies)
        {
            NSString * fileName =   [_delegate getResolvedPathForPath:[outStr substringWithRange:[ntcr range]]];
            [depencyList addObject:fileName];
        }
    }
    return depencyList;
}

# pragma mark - other things

// Make sure our local copy of _currentParentFiles is up to date.



-(NSDictionary *)getParentForFilepath:(NSString *)filepath
{
    __block NSDictionary * parent = nil;
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * s = [db executeQuery:@"SELECT * FROM js_files WHERE path = :path" withParameterDictionary:@{@"path": filepath}];
        if([s next])
        {
            FMResultSet * parentFile = s;
            int parent_id = [parentFile intForColumn:@"parent_id"];
            DDLogVerbose(@"JSMinify:: initial parent_id: %d", parent_id);
            //Find the parent Less file (parent_id = -1)
            //This could probably be done with one query, but I'm kind of bad with SQL recursion :welp:
            while(parent_id > -1)
            {
                [parentFile close];
                parentFile = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM js_files WHERE id = %d", parent_id]];
                if([parentFile next])
                {
                    parent_id = [parentFile intForColumn:@"parent_id"];
                }
            }
            parent = [parentFile resultDictionary];
        }
        else
        {
            DDLogError(@"JSMinify:: No DB entry found for file: %@", filepath);
        }
        [s close];
    }];
    
    return parent;
}


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
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        DDLogVerbose(@"JSMinify:: updateParentFilesWithCompletion");
        FMResultSet * d = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM js_files WHERE parent_id == -1 AND site_uuid == '%@'", [_delegate getCurrentSiteUUID]] ];
        if(_currentParentFiles == nil)
        {
            _currentParentFiles = [NSMutableArray array];
        }
        else
        {
            [_currentParentFiles removeAllObjects];
        }
        while([d next])
        {
            [_currentParentFiles addObject:[d resultDictionary]];
        }
        
        FMResultSet *s = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM js_files WHERE parent_id == -1 AND site_uuid == '%@'", [_delegate getCurrentSiteUUID]] ];
        if ([s next])
        {
            _currentParentFilesCount = [s intForColumnIndex:0];
        }
        
        if(handler != nil)
        {
            handler();
        }
        [s close];
        [d close];
    }];
}

// If the user chooses to update the css path of a less file to somewhere else.

-(void) updateMinifiedPath:(NSURL *)minifiedUrl forJSFile: (JSFiles *)jsFile
{
    NSString * minifiedPath = [_delegate getResolvedPathForPath:[minifiedUrl path]];
    [jsFile setMinified_path:minifiedPath];
    [[self managedObjectContext] save:nil];
}

-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url
{
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    NSString * cssFileName = [_delegate getResolvedPathForPath:[cssUrl path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * parentFile = [db executeQuery:@"SELECT * FROM js_files WHERE path == :path" withParameterDictionary:@{@"path":fileName}];
        if(![parentFile next])
        {
            DBERROR(@"JSMinify:: setCssPath: file %@ not found in db", fileName);
            return;
        }
        if([db executeUpdate:@"UPDATE js_files SET minified_path == :minified_path WHERE id == :id" withParameterDictionary:@{@"minified_path":cssFileName, @"id": [NSNumber numberWithInt:[parentFile intForColumn:@"id"]]}])
        {
            DDLogVerbose(@"JSMinify:: setCssPath: successfully set css path for file %@", fileName);
        }
        else
        {
            DBERROR(@"JSMinify:: setCssPath: error, %@",[db lastError]);
        }
        [parentFile close];
    }];
}

// Update preferences specific to each less file.

-(void) updateFileOptions:(NSDictionary *)options forFile:( JSFiles *)jsFile
{
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:options options:kNilOptions error:nil];
    NSString * preferenceString = [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding];
    [jsFile setOptions:preferenceString];
    [[self managedObjectContext] save:nil];
}

-(void) updateLessFilePreferences:(NSDictionary *)options forPath:(NSURL *) url
{
    
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:options options:kNilOptions error:nil];
    DDLogVerbose(@"JSMinify:: updating preferences to: %@", [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding]);
    
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        if([db executeUpdate:@"UPDATE js_files SET options == :val WHERE path == :path" withParameterDictionary:@{@"val": preferenceData, @"path" : fileName}])
        {
            DDLogVerbose(@"JSMinify:: updateLessFilePreferences: successfully updated preference for %@", fileName);
            DDLogVerbose(@"JSMinify:: updateLessFilePreferences: updated preferences to: %@", [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding]);
        }
        else
        {
            DBERROR(@"JSMinify:: updateLessFilePreferences: error: %@", [db lastError]);
        }
    }];
    
}

-(void) logToDatabase: (NSString *)format, ...
{
    va_list vl;
    va_start(vl, format);
    NSString* str = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    [self sendLineToLog:str :@"info"];
}

-(void) errorToDatabase: (NSString *)format, ...
{
    va_list vl;
    va_start(vl, format);
    NSString* str = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    [self sendLineToLog:str :@"error"];
}

-(void) sendLineToLog:(NSString *)line :(NSString *)type
{
    NSString * date = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                     dateStyle:NSDateFormatterShortStyle
                                                     timeStyle:NSDateFormatterLongStyle];
    NSDictionary * args = @{@"time": date, @"text": line, @"type":type };
    [_dbLog inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO log (time, text, type) VALUES (:time, :text, :type)" withParameterDictionary:args];
    }];
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
