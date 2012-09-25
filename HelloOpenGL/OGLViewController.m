//
//  OGLViewController.m
//  HelloOpenGL
//
//  Created by numask on 9/21/12.
//  Copyright (c) 2012 numask. All rights reserved.
//

#import "OGLViewController.h"
#import "OGLView.h"
@interface OGLViewController ()

@end

@implementation OGLViewController

@synthesize glView = _glView;
@synthesize screenShotButton;
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    CGRect frame = self.view.frame;
    frame = CGRectInset(frame, 100, 100);
    self.glView = [[OGLView alloc] initWithFrame:frame];
    [self.view addSubview:_glView];
    [self.view bringSubviewToFront:_glView];
    
}
- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    [_glView renderLineFromPoint:CGPointMake(500, 110) toPoint:CGPointMake(120, 330) withContainer:nil];
//    [_glView renderLineFromPoint:CGPointMake(123, 345) toPoint:CGPointMake(1, 77) withContainer:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(IBAction)screenShotButtonClicked:(id)sender
{
    NSLog(@"screenShotButtonClicked");
}

@end
