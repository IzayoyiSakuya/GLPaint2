//
//  DVDrawingCurve.m
//  draw on video-1
//
//  Created by numask on 8/10/12.
//
//

#import "DVDrawingCurve.h"

@implementation DVDrawingCurve


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.color];
    [aCoder encodeObject:self.elements];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.count]];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    
    self = [self init];
    if (self) {
        self.color = [aDecoder decodeObject];
        self.elements = [aDecoder decodeObject];
        self.count = [[aDecoder decodeObject] unsignedIntegerValue];
    }
    
    return self;
}



@end
