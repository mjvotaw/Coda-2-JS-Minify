//
//  TaskMan.h
//
//  Created by Michael Votaw on 1/16/15.
//
//

#import <Foundation/Foundation.h>

@interface JSMTaskMan : NSObject
{
    NSTask * _task;
    NSPipe * _outputPipe;
    NSPipe * _errorPipe;
    
    NSMutableData * _outputData;
    NSMutableData * _errorData;
    NSString * _output;
    NSString * _error;
    int _resultCode;
    
    NSString * _launchPath;
    NSArray * _arguments;
    NSArray * _modes;
    BOOL _isRunning;
}

-(id) initWithLaunchPath:(NSString *)launchPath AndArguments:(NSArray *)arguments;

-(void) launch;
-(BOOL) isRunning;
-(int) resultCode;
-(NSString *) getOutput;
-(NSString *) getError;
@end
