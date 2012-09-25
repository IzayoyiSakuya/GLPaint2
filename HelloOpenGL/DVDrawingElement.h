//
//  DVDrawingElement.h
//  draw on video-1
//
//  Created by numask on 8/10/12.
//
//

#import <Foundation/Foundation.h>

@interface DVDrawingElement : NSObject<NSCoding>


@property (nonatomic, assign) CGPoint position;
@property (nonatomic, strong) NSData * data;
@end
