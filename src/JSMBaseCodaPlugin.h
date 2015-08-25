#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"
#import "Growl.framework/Headers/Growl.h"
#import <asl.h>
@class CodaPlugInsController;

@interface JSMBaseCodaPlugin : NSObject <CodaPlugIn, NSUserNotificationCenterDelegate>
{
    NSString * currentSiteUUID;
    aslmsg msg;
    aslclient logClient;
}
@property (strong) 	CodaPlugInsController* controller;
@property (strong) NSObject <CodaPlugInBundle> * pluginBundle;
@property (strong) NSBundle * bundle;
@property (readwrite) BOOL verboseLogging;
- (id)initWithController:(CodaPlugInsController*)inController;
- (id)initWithController:(CodaPlugInsController*)inController andPlugInBundle:(NSObject <CodaPlugInBundle> *)p;
#pragma mark - open/save file dialogs
-(NSURL *) getFileNameFromUser;
-(NSURL *) getSaveNameFromUser;

#pragma mark - persistant storage methods
-(BOOL) doesPersistantFileExist:(NSString *)path;
-(BOOL) doesPersistantStorageDirectoryExist;
-(NSURL *) urlForPeristantFilePath:(NSString *)path;
-(NSError *) createPersistantStorageDirectory;
-(NSError *) copyFileToPersistantStorage:(NSString *)path;
#pragma mark - url/path helpers
-(NSString *) getResolvedPathForPath:(NSString *)path;
#pragma mark - NSUserNotification methods
-(void) sendUserNotificationWithTitle:(NSString *)title andMessage:(NSString *)message;
-(void) sendUserNotificationWithTitle:(NSString *)title sound:(NSString *)sound andMessage:(NSString * ) message;
#pragma mark - OS X Compatability methods
-(id) getNibNamed:(NSString *)nibName forClass:(Class)nibClass;
-(NSArray *) loadNibNamed:(NSString *)nibName;
#pragma mark - system logging
-(void) logMessage:(NSString *)message;
-(void) logError:(NSString *)errorMessage;
#pragma mark - other helpers
-(BOOL) isSiteOpen;
-(NSString *) getCurrentSiteUUID;
-(NSString *) updateCurrentSiteUUID;
@end
