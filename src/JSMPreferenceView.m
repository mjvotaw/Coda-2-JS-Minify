//
//  PreferenceView.m
//  LESSCompile
//
//  Created by Michael on 5/1/14.
//
//

#import "JSMPreferenceView.h"

@implementation JSMPreferenceView


-(BOOL)acceptsFirstResponder
{
    return true;
}

-(void)cancelOperation:(id)sender
{
    [self.window close];
}

@end
