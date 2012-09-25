//
//  DVDrawingElement.m
//  draw on video-1
//
//  Created by numask on 8/10/12.
//
//

#import "DVDrawingElement.h"

@implementation DVDrawingElement

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSValue valueWithCGPoint:self.position]];
    [aCoder encodeObject:self.data];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    
    self = [self init];
    if (self) {
        self.position = [[aDecoder decodeObject] CGPointValue];
        self.data = [aDecoder decodeObject];
    }    
    return self;
}


@end
