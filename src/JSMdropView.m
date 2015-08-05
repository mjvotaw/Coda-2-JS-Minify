//
//  dropView.m
//  LESSCompile
//
//  Created by Michael on 4/21/14.
//
//

#import "JSMdropView.h"

@implementation JSMdropView

- (id)initWithCoder:(NSCoder *)coder
{
    self=[super initWithCoder:coder];
    if (self) {
		[self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
   return NSDragOperationEvery;
}

-(NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationEvery;
}
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return true;
}


-(BOOL)acceptsFirstResponder
{
    return true;
}

-(void)cancelOperation:(id)sender
{
    [self.window close];
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    if(self.delegate)
    {
        [self.delegate draggingDestinationPerformedDragOperation:sender];
    }
    
    return true;
}

@end
