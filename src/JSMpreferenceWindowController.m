//
//  preferenceWindowController.m
//  LESSCompile
//
//  Created by Michael on 11/12/14.
//
//

#import "JSMpreferenceWindowController.h"
#import "JSMDb.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "FileView.h"
#import "JSMkeyPrefButton.h"

static int ddLogLevel;
static NSString * COMPVERSION = @"1.1.2";
static NSString * LESSVERSION = @"2.4.23";
@interface JSMpreferenceWindowController ()

@end

@implementation JSMpreferenceWindowController

-(instancetype)init
{
    if(self = [super initWithWindowNibName:@"JSMpreferenceWindowController"])
    {
        Ldb = [JSMDb sharedLessDb];
        DDLogVerbose(@"JSMinify:: preferenceWindowController init'd");
    }
    return self;
}


- (void)windowDidLoad {
    [super windowDidLoad];
    if(Ldb.prefs == nil)
    {
        DDLogVerbose(@"JSMinify:: prefs is nil");
    }
    
    for(JSMkeyPrefButton * button in self.view.subviews)
    {
        if([button isKindOfClass:[JSMkeyPrefButton class]])
        {
            [button setTarget:self];
            [button setAction:@selector(userChangedPreference:)];
            NSString * prefKey = [button valueForKey:@"prefKey"];
            NSNumber * val = [Ldb.prefs objectForKey:prefKey];
            DDLogVerbose(@"JSMinify:: Preference: %@ : %@", prefKey, val);
            if(val != nil)
            {
                [button setState:[val integerValue]];
            }

        }
    }
    
    [self.lessVersion setStringValue:LESSVERSION];
    [self.compilerVersion setStringValue:COMPVERSION];
    
}


- (IBAction)userChangedPreference:(NSButton *)sender
{
    if( ![sender isKindOfClass:[JSMkeyPrefButton class]] || [sender valueForKey:@"prefKey"] == nil)
    {
        return;
    }
    
    NSString * pref = [sender valueForKey:@"prefKey"];
    NSNumber * newState = [NSNumber numberWithInteger:[sender state]];
    DDLogVerbose(@"JSMinify:: setting preference %@ : %@", pref, newState);
    [Ldb updatePreferenceNamed:pref withValue:newState];
    
    if([pref isEqualToString:@"verboseLog"])
    {
        if([sender state] == NSOffState)
        {
            ddLogLevel = LOG_LEVEL_ERROR;
            DDLogError(@"JSMinify:: Verbose logging disabled.");
        }
        else if([sender state] == NSOnState)
        {
            ddLogLevel = LOG_LEVEL_VERBOSE;
            DDLogVerbose(@"JSMinify:: Verbose logging enabled.");
        }
    }
}

- (IBAction)viewGithub:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/mjvotaw/Coda-2-LESS-Compiler"]];
    
}


@end
