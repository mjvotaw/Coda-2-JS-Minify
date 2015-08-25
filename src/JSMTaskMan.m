//
//  TaskMan.m
//
//  Created by Michael Votaw on 1/16/15.
//
//

#import "JSMTaskMan.h"

@implementation JSMTaskMan


-(id)initWithLaunchPath:(NSString *)launchPath AndArguments:(NSArray *)arguments
{
    if(self = [super init])
    {
        _launchPath = launchPath;
        _arguments = arguments;
        _modes = @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode,@"JSMTaskMan"];
    }
    return self;
}


-(void)launch
{
    _task = [self createTask];
    _outputPipe = [self openPipeWithSelector:@selector(gotOutput:)];
    _errorPipe = [self openPipeWithSelector:@selector(gotError:)];
    
    _task.standardOutput = _outputPipe;
    _task.standardError = _errorPipe;
    _task.standardInput = [NSPipe pipe];
    _outputData = [NSMutableData data];
    _errorData = [NSMutableData data];
    
   [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(exited:) name: NSTaskDidTerminateNotification object: _task];
    
    _isRunning = true;
    
    NSFileHandle * file = [_outputPipe fileHandleForReading];
    [_task launch];
//    [_task waitUntilExit];
    [self waitTillFinishedInMode: @"JSMTaskMan"];
    
    NSData * data = [file readDataToEndOfFile];
    [_outputData appendData:data];

}


- (void) waitTillFinishedInMode: (NSString*)runLoopMode
{
    // wait for task to exit:
    while( _task.isRunning || _isRunning )
        if (![[NSRunLoop currentRunLoop] runMode: runLoopMode
                                      beforeDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]])
        {
            // This happens if both stderr and stdout are closed (leaving no NSFileHandles running
            // in this runloop mode) but the task hasn't yet notified me that it exited.
            // For some reason, in 10.6 the notification sometimes just doesn't appear, so poll
            // for it:
            if (_task.isRunning)
            {
                sleep(1);
            }
            else
            {
                [self exited: nil];
            }
        }

}


- (BOOL) shouldFinish
{
    return _isRunning && !_task.isRunning;
}

-(void) finish
{
    if(!_isRunning) //finish has already been called?
    {
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _resultCode = _task.terminationStatus;
    _isRunning = false;
    
}

-(BOOL) isRunning
{
    return _isRunning || _task.isRunning;
}

-(int) resultCode
{
    return _resultCode;
}

#pragma mark - object creation

-(NSTask *) createTask
{
    NSTask * task = [[NSTask alloc] init];
    task.launchPath = _launchPath;
    task.arguments = _arguments;
    return task;
}

-(NSPipe *)openPipeWithSelector: (SEL) selector
{
    NSPipe * pipe = [NSPipe pipe];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:selector name:NSFileHandleDataAvailableNotification object:[pipe fileHandleForReading]];
    
    [[pipe fileHandleForReading] waitForDataInBackgroundAndNotifyForModes:_modes];
    
    return pipe;
}



#pragma mark - output/error handlers

-(void)gotOutput:(NSNotification *)notification
{

    if( notification.object == [_outputPipe fileHandleForReading] )
    {
        NSData * data = [notification.object availableData];
        if([data length] > 0)
        {
            [[_outputPipe fileHandleForReading] waitForDataInBackgroundAndNotifyForModes:_modes];
            [_outputData appendData:data ];
        }
        else
        {
            if([self shouldFinish])
            {
                [self finish];
            }
        }
    }
}

-(void) gotError:(NSNotification *)notification
{

    if( notification.object == [_errorPipe fileHandleForReading] )
    {
        NSData *data = [notification.object availableData];
        if([data length] > 0)
        {
            [[_errorPipe fileHandleForReading] waitForDataInBackgroundAndNotifyForModes:_modes];
            [_errorData appendData:data ];
        }
        else
        {
            if([self shouldFinish])
            {
                [self finish];
            }
        }
    }
}

-(void) exited:(NSNotification *)notification
{
    _resultCode = _task.terminationStatus;
    if([self shouldFinish])
    {
        [self finish];
    }
    else
    {
         [self performSelector: @selector(finish) withObject: nil afterDelay: 0.5];
    }
}


#pragma mark - output/error

-(NSString *) getOutput
{
    NSString * output = [[NSString alloc] initWithData: _outputData encoding: NSUTF8StringEncoding];
    return output;
}


-(NSString *) getError
{
    NSString * error = [[NSString alloc] initWithData: _errorData encoding: NSUTF8StringEncoding];
    return error;
}
@end
