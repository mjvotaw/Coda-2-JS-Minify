//
//  LessDb.h
//  LESSCompile
//
//  Created by Michael on 10/26/14.
//
//

/* This object contains most of the methods for loading and modifying the database. */

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseQueue.h"
#import "JSMBaseCodaPlugin.h"
#import "JSMTaskMan.h"
#import "JSFiles.h"
#import "JSMPreferences.h"

@protocol LessDbDelegate <NSObject>


@end

@interface JSMDb : NSObject
{
    /* indexing tasks and pipes */
    JSMTaskMan * tm;
    
    NSTask * indexTask;
    NSPipe * indexPipe;
    NSPipe * errorPipe;
    NSMutableArray * dependencyQueue;
    NSString * indexOutput;
    NSString * dependsPath;
}
@property (strong) JSMBaseCodaPlugin <LessDbDelegate> * delegate;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;

@property (strong) FMDatabaseQueue * dbQueue;
@property (strong) FMDatabaseQueue * dbLog;

@property (strong) JSMPreferences * internalPreferences;
@property (strong) NSMutableDictionary * prefs;
@property (strong) NSMutableArray * currentParentFiles;
@property (readwrite) int currentParentFilesCount;
@property (readwrite) BOOL isDepenencying;

+(JSMDb *)sharedLessDb;
-(JSMDb *) initWithDelegate:(JSMBaseCodaPlugin <LessDbDelegate> *)d;
-(void) setupDb;
-(void) setupLog;

-(void) updateParentFilesListWithCompletion:(void(^)(void))handler;
-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val;
-(void) registerFile:(NSURL *)url;
-(void) unregisterFile:(NSURL *)url;
-(void) unregisterFileWithId:(NSManagedObjectID *)fileId;
-(NSDictionary *) getParentForFilepath:(NSString *)filepath;

-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url;
-(void) updateLessFilePreferences:(NSDictionary *)options forPath:(NSURL *) url;
-(void) addDependencyCheckOnFile:(NSString *)path;


-(void) updateParentFilesList;
-(void) updateMinifiedPath:(NSURL *)minifiedUrl forJSFile: (JSFiles *)jsFile;
-(void) updateFileOptions:(NSDictionary *)options forFile:( JSFiles *)jsFile;
@end
