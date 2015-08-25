//
//  Created by Michael on 10/26/14.
//
//

/* This object contains most of the methods for loading and modifying the database. */

#import <Foundation/Foundation.h>
#import "JSMBaseCodaPlugin.h"
#import "JSMTaskMan.h"
#import "JSFiles.h"
#import "JSMPreferences.h"

@protocol JSDbDelegate <NSObject>


@end

@interface JSMDb : NSObject
{

}
@property (strong) JSMBaseCodaPlugin <JSDbDelegate> * delegate;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;



@property (strong) JSMPreferences * internalPreferences;
@property (strong) NSMutableDictionary * prefs;

@property (strong) NSMutableArray * currentParentFiles;
@property (readwrite) int currentParentFilesCount;

+(JSMDb *)SharedJSDb;
-(JSMDb *) initWithDelegate:(JSMBaseCodaPlugin <JSDbDelegate> *)d;

// things to keep
- (void)saveContext;
-(void) setupDb;
-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val;

-(void) registerFile:(NSURL *)url;
-(void) unregisterFileWithId:(NSManagedObjectID *)fileId;
-(JSFiles *)JSFileForFilePath:(NSString *)filePath;

-(void) updateParentFilesList;
-(void) updateParentFilesListWithCompletion:(void(^)(void))handler;
-(void) updateMinifiedPath:(NSURL *)minifiedUrl forJSFile: (JSFiles *)jsFile;
-(void) updateFileOptions:(NSDictionary *)options forFile:( JSFiles *)jsFile;
@end
