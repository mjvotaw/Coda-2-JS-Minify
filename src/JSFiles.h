//
//  JSFiles.h
//  JSMinify
//
//  Created by Michael Votaw on 8/5/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class JSFiles;

@interface JSFiles : NSManagedObject

@property (nonatomic, retain) NSString * minified_path;
@property (nonatomic, retain) NSString * options;
@property (nonatomic, retain) NSString * path;
@property (nonatomic, retain) NSString * site_uuid;
@property (nonatomic, retain) JSFiles *parent;

@end
