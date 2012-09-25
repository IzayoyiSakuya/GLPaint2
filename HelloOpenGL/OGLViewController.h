//
//  OGLViewController.h
//  HelloOpenGL
//
//  Created by numask on 9/21/12.
//  Copyright (c) 2012 numask. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OGLView.h"

@interface OGLViewController : UIViewController
{
    OGLView * _glView;
}

@property (nonatomic, strong)  OGLView * glView;
@property (nonatomic, weak) IBOutlet UIButton * screenShotButton;

-(IBAction)screenShotButtonClicked:(id)sender;


@end
