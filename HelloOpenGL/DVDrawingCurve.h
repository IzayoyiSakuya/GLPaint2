//
//  DVDrawingCurve.h
//  draw on video-1
//
//  Created by numask on 8/10/12.
//
//

#import <Foundation/Foundation.h>




@interface DVDrawingCurve : NSObject<NSCoding>


@property (nonatomic, strong) UIColor * color;
@property (nonatomic, strong) NSMutableArray * elements;
@property (nonatomic, assign) NSUInteger count;

@end
