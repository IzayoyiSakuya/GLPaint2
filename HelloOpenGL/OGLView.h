//
//  OGLView.h
//  HelloOpenGL
//
//  Created by numask on 9/21/12.
//  Copyright (c) 2012 numask. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include "DVDrawingCurve.h"
#import <AVFoundation/AVFoundation.h>
typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

@class DVDrawingElement;

@interface OGLView : UIView
{
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    
    GLuint _colorRenderBuffer;
    GLuint _frameBuffer;
    GLuint _depthRenderBuffer;
    
    GLuint _positionSlot;
    GLuint _colorSlot;
    GLuint _brushSizeSlot;
    GLuint _textureSlot;
    GLuint _programHandle;
    
    UIColor * _currentColor;
    GLuint _brushTexture;
    float _brushWidth;
    float _brushHeight;
    
    BOOL firstTouch;
    CGPoint location;
    CGPoint previousLocation;
    
    Vertex * vertexBuffer;
    NSUInteger vertexMax;
    
    NSMutableArray * drawingCurves;
    DVDrawingCurve * currentDrawingCurve;
    
    GLuint _drawingVBO;
    GLuint _dataFBO;
    GLuint _dataRenderBuffer;
    
    CVOpenGLESTextureCacheRef coreVideoTextureCache;
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
    CVPixelBufferPoolRef renderPixelBufferPool;
    
    
    NSURL *movieURL;
    NSString *fileType;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterAudioInput;
	AVAssetWriterInput *assetWriterVideoInput;
    AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferInput;
	dispatch_queue_t movieWritingQueue;
    
    BOOL needDrawVBO;
    
}

@property (nonatomic, strong) UIColor * penColor;

- (void) renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end withContainer:(DVDrawingElement*)elem;
- (void)initializeMovieWithOutputSettings:(NSDictionary*)outputSettings;
- (UIImage *)openGLViewScreenShot;
- (UIImage *)openGLViewScreenShotES1;

@end
