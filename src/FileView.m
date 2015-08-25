//
//  FileView.m
//  JSMinify
//
//  Created by Michael on 10/30/13.
//
//

#import "FileView.h"
#import "JSMkeyPrefButton.h"

@implementation JSMFileView

-(void) setupOptionsWithSelector:(SEL)aSelector andTarget:(id)target;
{
    NSArray * subviews = [self.subviews arrayByAddingObjectsFromArray:self.advancedSettingsView.subviews];
    
    //get all of the regular checkboxes
    for(NSButton * button in subviews)
    {
        if([button isKindOfClass:[JSMkeyPrefButton class]] && [button valueForKey:@"prefKey"] != nil)
        {
            [button setAction:aSelector];
            [button setTarget:target];
        }
    }
    
}



-(void) setCheckboxesForOptions:(NSDictionary *)options
{
    NSArray * subviews = [self.subviews arrayByAddingObjectsFromArray:self.advancedSettingsView.subviews];
    
    //get all of the regular checkboxes
    for(NSButton * button in subviews)
    {
        if([button isKindOfClass:[JSMkeyPrefButton class]] &&[button valueForKey:@"prefKey"] != nil)
        {
            NSString * option = [button valueForKey:@"prefKey"];
            if([options objectForKey:option] != nil)
            {
                [button setState:[[options objectForKey:option] integerValue]];
            }
        }
    }
}

-(NSDictionary *) getOptionValues
{
    NSMutableDictionary * options = [NSMutableDictionary dictionary];
    NSArray * subviews = [self.subviews arrayByAddingObjectsFromArray:self.advancedSettingsView.subviews];
    
    //get all of the regular checkboxes
    for(NSButton * button in subviews)
    {
        if([button isKindOfClass:[JSMkeyPrefButton class]] &&[button valueForKey:@"prefKey"] != nil)
        {
            NSString * option = [button valueForKey:@"prefKey"];
            [options setObject:@(button.state) forKey:option];
        }
    }
    
    return options;
}

@end
