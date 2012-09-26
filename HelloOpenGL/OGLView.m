//
//  OGLView.m
//  HelloOpenGL
//
//  Created by numask on 9/21/12.
//  Copyright (c) 2012 numask. All rights reserved.
//

#import "OGLView.h"
#import "CC3GLMatrix.h"
#import "DVDrawingElement.h"
#import <CoreVideo/CoreVideo.h>


#define kBrushOpacity		(1.0 / 3.0)
#define kBrushPixelStep		3
#define kBrushScale			2
#define kLuminosity			0.75
#define kSaturation			1.0
#define CHECK_GL checkGL()
#define BUFFER_OFFSET(i) ((char*)NULL + (i))

const Vertex Vertices[] = {
    {{100, 170, 0}, {1, 0, 0, 1}},
    {{35, 18, 0}, {0, 1, 0, 1}},
//    {{-1, 1, 0}, {0, 0, 1, 1}},
//    {{-1, -1, 0}, {0, 0, 0, 1}}
//    {{10, 10, 0}, {1, 0, 0, 1}},
//    {{20, 20, 0}, {1, 0, 0, 1}},
};

const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0
};


float pfIdentity[] =
{
    -1.0f,0.0f,0.0f,0.0f,
    0.0f,1.0f,0.0f,0.0f,
    0.0f,0.0f,1.0f,0.0f,
    0.0f,0.0f,0.0f,1.0f
};

@implementation OGLView

@synthesize penColor;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        vertexBuffer = NULL;
        vertexMax = 64;
        [self initializeMovieWithOutputSettings:nil];
        
        [self setupLayer];
        CHECK_GL;
        [self setupContext];
                CHECK_GL;
        [self setupFrameBuffer];
        CHECK_GL;
        
        [self setupRenderBuffer];
                CHECK_GL;
        [self connectFrameBufferRenderBuffer];
        CHECK_GL;
//        [self setupDataFBO];
//        CHECK_GL;
        [self compileShaders];
                CHECK_GL;
        [self setupVBOs];
                CHECK_GL;

        drawingCurves = [[NSMutableArray alloc]init];
        _currentColor = [UIColor yellowColor];
        glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
                CHECK_GL;
        // 1
        glViewport(0, 0, self.frame.size.width, self.frame.size.height);
//        [self renderBackground];
                CHECK_GL;
        [self setupTexture];
        CHECK_GL;
        glDisable(GL_DITHER);
                CHECK_GL;
        glEnable(GL_BLEND);
                CHECK_GL;
		// Set a blending function appropriate for premultiplied alpha pixel data
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                CHECK_GL;
        [self renderBackground];
                CHECK_GL;
//        [self renderLineFromPoint:CGPointMake(500, 110) toPoint:CGPointMake(120, 330) withContainer:nil];

    }
    return self;
}

+ (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return (CVOpenGLESTextureCacheCreate != NULL);
#endif
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{
//    // Drawing code
////    [super drawRect:rect];
//    [self renderVBOBuffers];
//}

- (void)dealloc
{
    _context = nil;
}


+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void) layoutSubviews
{
    [super layoutSubviews];
    if (![EAGLContext setCurrentContext:_context]) {
//        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
//    [self destroyRenderBuffer];
//    
//
//    [self setupRenderBuffer];
//    [self setupFrameBuffer];
}

- (void)setupLayer {
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES
                                                                                ], kEAGLDrawablePropertyRetainedBacking,
                                     kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                     nil];
}

- (void)setupContext {
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}


- (void)setupRenderBuffer {

    if (!_colorRenderBuffer) {
        [self createRenderBuffer];
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    CHECK_GL;
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    CHECK_GL;
}

- (void) createRenderBuffer {
    glGenRenderbuffers(1, &_colorRenderBuffer);
    CHECK_GL;
}

- (void) destroyRenderBuffer {
    glDeleteFramebuffers(1, &_frameBuffer);
	_frameBuffer = 0;
	glDeleteRenderbuffers(1, &_colorRenderBuffer);
	_colorRenderBuffer = 0;
	
	if(_depthRenderBuffer)
	{
		glDeleteRenderbuffers(1, &_depthRenderBuffer);
		_depthRenderBuffer = 0;
	}
}

- (void)setupFrameBuffer {

    if (!_frameBuffer) {
        [self createFrameBuffer];
        CHECK_GL;
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    CHECK_GL;

}
- (void) connectFrameBufferRenderBuffer {
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
    CHECK_GL;
}

- (void) createFrameBuffer
{
    glGenFramebuffers(1, &_frameBuffer);
}

- (void) createDataFBO
{
    glActiveTexture(GL_TEXTURE1);
//    glGenFramebuffers(1, &_dataFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    if ([OGLView supportsFastTextureUpload])
    {
#if defined(__IPHONE_6_0)
        //        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [[GPUImageOpenGLESContext sharedImageProcessingOpenGLESContext] context], NULL, &coreVideoTextureCache);
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &coreVideoTextureCache);
#else
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge void *)[[GPUImageOpenGLESContext sharedImageProcessingOpenGLESContext] context], NULL, &coreVideoTextureCache);
#endif
        
        if (err)
        {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
        
        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        BOOL useExternalPixelBufferPool = NO;
        CVPixelBufferPoolRef pbPool = NULL;
        if (useExternalPixelBufferPool) {
            //            pbPool = [assetWriterPixelBufferInput pixelBufferPool];
        }
        else
        {
            BOOL result = [self createBufferPool:&pbPool];
            NSAssert(result, @"buffer pool created failed.");
            renderPixelBufferPool = pbPool;
        }
        
        
        
        
        
        CFDictionaryRef empty; // empty value for attr value.
        CFMutableDictionaryRef attrs;
        empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                                   NULL,
                                   NULL,
                                   0,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   &kCFTypeDictionaryValueCallBacks);
        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                          1,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
        
        CFDictionarySetValue(attrs,
                             kCVPixelBufferIOSurfacePropertiesKey,
                             empty);
        
        //CVPixelBufferPoolCreatePixelBuffer (NULL, [assetWriterPixelBufferInput pixelBufferPool], &renderTarget);
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            (int)self.frame.size.width,
                            (int)self.frame.size.height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &renderTarget);
        
        
        
        err =  CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, coreVideoTextureCache, renderTarget,
                                                             NULL, // texture attributes
                                                             GL_TEXTURE_2D,
                                                             GL_RGBA, // opengl format
                                                             /*(int)videoSize.width,*/(int)self.frame.size.width,
                                                             /*(int)videoSize.height,*/(int)self.frame.size.height,
                                                             GL_BGRA, // native iOS format
                                                             GL_UNSIGNED_BYTE,
                                                             0,
                                                             &renderTexture);
        if (err)
        {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        CFRelease(attrs);
        CFRelease(empty);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        CHECK_GL;
        //        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        //        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        CHECK_GL;
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        CHECK_GL;
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
        CHECK_GL;
    }
    else
    {
        //        glGenRenderbuffers(1, &movieRenderbuffer);
        //        glBindRenderbuffer(GL_RENDERBUFFER, movieRenderbuffer);
        //        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, (int)videoSize.width, (int)videoSize.height);
        //        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, movieRenderbuffer);
    }
    
	
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);

}

- (void) setupDataFBO
{
    if (!_dataFBO) {
        [self createDataFBO];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
}

- (UIImage *)openGLViewScreenShot
{
    // NSLog(@"Just took an OpenGL picture");
    [self setupDataFBO];
    CHECK_GL;
    [self renderVBOBuffers];
    CHECK_GL;
    
    // Get the size of the backing CAEAGLLayer
    GLint localBackingWidth;
    GLint localBackingHeight;
    GLint colorRenderbuffer = 0;
    

    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    CHECK_GL;
//    glGetBufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &localBackingWidth);
//    CHECK_GL;
//    glGetBufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &localBackingHeight);
//    CHECK_GL;
//    glBindRenderbuffer(GL_RENDERBUFFER_OES, colorRenderbuffer);
//    glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &localBackingWidth);
//    glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &localBackingHeight);
    
    BOOL _CVOpenGLESTextureSupported = NO;
    
    if (_CVOpenGLESTextureSupported) {
        //
    }
    else
    {
//        NSInteger x = 0;
//        NSInteger y = 0;
        NSInteger width = CVPixelBufferGetWidth(renderTarget);
        NSInteger height = CVPixelBufferGetHeight(renderTarget);
        NSInteger dataLength = width * height * 4;
        GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
        OSType imageType = CVPixelBufferGetPixelFormatType(renderTarget);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(renderTarget);
        size_t bytesOfData = CVPixelBufferGetDataSize(renderTarget);
        // Read pixel data from the framebuffer
//        glPixelStorei(GL_PACK_ALIGNMENT, 4);
//        glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
        CHECK_GL;
        CVPixelBufferLockBaseAddress(renderTarget, 0);
        GLubyte * _rawBytesForImage = (GLubyte *)CVPixelBufferGetBaseAddress(renderTarget);
        // Do something with the bytes
//        CVPixelBufferUnlockBaseAddress(renderTarget, 0);

        
        // Create a CGImage with the pixel data
        // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
        // otherwise, use kCGImageAlphaPremultipliedLast
        CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, _rawBytesForImage, /*dataLength*/ bytesOfData, NULL);
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGImageRef iref = CGImageCreate(
                                        width,
                                        height,
                                        8,
                                        32,
                                        bytesPerRow, //width * 4,
                                        colorspace,
                                        kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                        ref, NULL, true, kCGRenderingIntentDefault);
        CHECK_GL;

        
        // OpenGL ES measures data in PIXELS
        // Create a graphics context with the target size measured in POINTS
        NSInteger widthInPoints;
        NSInteger heightInPoints;
        if (NULL != UIGraphicsBeginImageContextWithOptions) {
            // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
            // Set the scale parameter to your OpenGL ES view's contentScaleFactor
            // so that you get a high-resolution snapshot when its value is greater than 1.0
            CGFloat scale = self.contentScaleFactor;
            widthInPoints = width / scale;
            heightInPoints = height / scale;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, scale);
        }
        else {
            // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
            widthInPoints = width;
            heightInPoints = height;
            UIGraphicsBeginImageContext(CGSizeMake(widthInPoints, heightInPoints));
        }
        
        CGContextRef cgcontext = UIGraphicsGetCurrentContext();
        
        // UIKit coordinate system is upside down to GL/Quartz coordinate system
        // Flip the CGImage by rendering it to the flipped bitmap context
        // The size of the destination area is measured in POINTS
        CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
        CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), iref);
        
        // Retrieve the UIImage from the current context
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        CVPixelBufferUnlockBaseAddress(renderTarget, 0);
        // Clean up
        free(data);
        CFRelease(ref);
        CFRelease(colorspace);
        CGImageRelease(iref);
        
        // return to framebuffer/renderbuffer

//        [self setupFrameBuffer];
//        [self setupRenderBuffer];
//        [self connectFrameBufferRenderBuffer];
//        [self destroyVertexBufferObject];
//        [self setupVBOs];
        
        //
        // Set the resulting image to the openGLScreenshotImage image.
        //
        CHECK_GL;
        return image;
        
    }
    return nil;
}

- (BOOL) createBufferPool:(CVPixelBufferPoolRef*)bufferPoolPtr
{
    
    NSMutableDictionary * dict = [[NSMutableDictionary alloc]init];
    
    int pixelFormat = kCVPixelFormatType_32ARGB;
    [dict setObject:[NSNumber numberWithInt:pixelFormat] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    
    int width = self.frame.size.width;
    [dict setObject:[NSNumber numberWithInt:width] forKey:(NSString*)kCVPixelBufferWidthKey];

    int height = self.frame.size.height;
    [dict setObject:[NSNumber numberWithInt:height] forKey:(NSString*)kCVPixelBufferHeightKey];


//    [dict setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCVPixelBufferOpenGLCompatibilityKey];
//    [dict setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCVPixelBufferCGImageCompatibilityKey];    
    
    NSDictionary *IOSurfaceProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES], @"IOSurfaceOpenGLESFBOCompatibility",[NSNumber numberWithBool:YES], @"IOSurfaceOpenGLESTextureCompatibility",nil];
    [dict setObject:IOSurfaceProperties forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
    
//    CFNumberRef pixelFormatNumber = CFNumberCreate (kCFAllocatorDefault, kCFNumberIntType, &pixelFormat);
//    
//    int width = self.frame.size.width;
//    CFNumberRef widthNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &width);
//    
//    int height = self.frame.size.height;
//    CFNumberRef heightNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &height);
    
//    CFBooleanRef openGLCompatible = kCFBooleanTrue;
    
//    CFDictionaryKeyCallBacks keyCallBack = kCFTypeDictionaryKeyCallBacks;
//    CFDictionaryValueCallBacks valueCallBack = kCFTypeDictionaryValueCallBacks;
//    NSUInteger entryCount;
//#if defined(__IPHONE_6_0)
//    entryCount = 4;
//#else
//    entryCount = 3;
//#endif
//    
//    CFMutableDictionaryRef dictionaryRef = CFDictionaryCreateMutable (kCFAllocatorDefault, entryCount, &keyCallBack, &valueCallBack);
//    
//    
//    CFDictionarySetValue(dictionaryRef, kCVPixelBufferPixelFormatTypeKey,  pixelFormatNumber);
//    CFDictionarySetValue(dictionaryRef, kCVPixelBufferWidthKey, widthNumber);
//    CFDictionarySetValue(dictionaryRef, kCVPixelBufferHeightKey, heightNumber);
//#if defined(__IPHONE_6_0)
//    CFDictionarySetValue(dictionaryRef, kCVPixelBufferOpenGLESCompatibilityKey, kCFBooleanTrue);
//#endif
    CVReturn theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)dict, bufferPoolPtr);
    if (theError)
    {
        NSAssert(NO, @"Error at CVPixelBufferPoolCreate %d", theError);
        return NO;
    }
    else
    {
        return YES;
    }
    
}

- (void)destroyDataFBO;
{
    [EAGLContext setCurrentContext:_context];
    
    if (_dataFBO)
	{
		glDeleteFramebuffers(1, &_dataFBO);
		_dataFBO = 0;
	}
    
    if (_dataRenderBuffer)
	{
		glDeleteRenderbuffers(1, &_dataRenderBuffer);
		_dataRenderBuffer = 0;
	}
    
    if ([OGLView supportsFastTextureUpload])
    {
        if (coreVideoTextureCache)
        {
            CFRelease(coreVideoTextureCache);
        }
        
        if (renderTexture)
        {
            CFRelease(renderTexture);
        }
        if (renderTarget)
        {
            CVPixelBufferRelease(renderTarget);
        }
        
    }
}

- (void)renderBackground {
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 1
//    glOrthof(0, self.frame.size.width, 0, self.frame.size.height, -1, 1);
//    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
//    glMatrixMode(GL_MODELVIEW);
    
    // 2
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) *3));
    
    glUniform1i(_textureSlot, 1);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _brushTexture);
//    glEnable(GL_TEXTURE_2D);
//
    // 3
    glDrawArrays(GL_POINTS, 0, 2);
//    glDrawElements(GL_POINTS, 1, GL_UNSIGNED_BYTE, 0);
//    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]),
//                   GL_UNSIGNED_BYTE, 0);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    
    // 1
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:@"glsl"];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    // 2
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 3
    const char* shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4
    glCompileShader(shaderHandle);
    
    // 5
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
    
}

- (void)compileShaders {
    
    // 1
    GLuint vertexShader = [self compileShader:@"SimpleVertex"
                                     withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"SimpleFragment"
                                       withType:GL_FRAGMENT_SHADER];
    
    // 2
    GLuint programHandle = glCreateProgram();
    _programHandle = programHandle;
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    // 3
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    // 4
    glUseProgram(programHandle);
    
    // 5
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    GLuint projection = glGetUniformLocation(programHandle, "Projection");
    
    GLfloat projectionMat[16];
    projectionMat[0] = 2.0 / self.frame.size.width;
    projectionMat[1] = 0.0;
    projectionMat[2] = 0.0;
    projectionMat[3] = -1.0;
    
    projectionMat[4] = 0.0;
    projectionMat[5] = 2.0 / self.frame.size.height;
    projectionMat[6] = 0.0;
    projectionMat[7] = -1.0;
    
    projectionMat[8] = 0.0;
    projectionMat[9] = 0.0;
    projectionMat[10] = -1.0;
    projectionMat[11] = 0.0;
    
    projectionMat[12] = 0.0;
    projectionMat[13] = 0.0;
    projectionMat[14] = 0.0;
    projectionMat[15] = 1.0;
    
    glUniformMatrix4fv( projection, 1, GL_FALSE, projectionMat);
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
}

- (void)setupVBOs {
    
    if (!_drawingVBO) {
        [self createDrawingVBOs];
        CHECK_GL;
    }
    
    [self initializeVertexBufferObject];
    CHECK_GL;
    
//    GLuint indexBuffer;
//    glGenBuffers(1, &indexBuffer);
//    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
//    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
//    
}

- (void) createDrawingVBOs {
    glGenBuffers(1, &_drawingVBO);
    CHECK_GL;
}

- (void) initializeVertexBufferObject
{
    glBindBuffer(GL_ARRAY_BUFFER, _drawingVBO);
    CHECK_GL;
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices) * vertexMax, NULL, GL_STREAM_DRAW);
    CHECK_GL;
}

- (void) destroyVertexBufferObject
{
    glDeleteBuffers(1, &_drawingVBO);
    CHECK_GL;
}

- (void) renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end withContainer:(DVDrawingElement*)container
{
//	static Vertex*		vertexBuffer = NULL;
//	static NSUInteger	vertexMax = 64;
	NSUInteger			vertexCount = 0,
    count,
    i;

    BOOL needRenderVBO = NO;
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);

    
//    [self setupFrameBuffer];
    [self setupRenderBuffer];
    [self connectFrameBufferRenderBuffer];
    [self setupVBOs];
	// Convert locations from Points to Pixels
	CGFloat scale = self.contentScaleFactor;
	start.x *= scale;
	start.y *= scale;
	end.x *= scale;
	end.y *= scale;
    
    float r, g, b, a;
    [_currentColor getRed:&r green:&g blue:&b alpha:&a];
    
	// Add points to the buffer so there are drawing points every X pixels
	count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);

    
    if (vertexBuffer == NULL) {
        vertexBuffer = malloc(vertexMax * sizeof(Vertex));
    }
    if(count >= vertexMax) {
        needRenderVBO = YES;
        while (count >= vertexMax) {
            vertexMax *= 2;
        }
        vertexBuffer = realloc(vertexBuffer, vertexMax * sizeof(Vertex));
        [self destroyVertexBufferObject];
        [self initializeVertexBufferObject];
    }
    
    
    NSLog(@"start:%@ --- end: %@, count=%d", [NSValue valueWithCGPoint:start], [NSValue valueWithCGPoint:end], count);
    
	for(i = 0; i < count; ++i) {

		vertexBuffer[i].Position[0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[i].Position[1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[i].Position[2] = 0.0f;        
        
        // color is RGBA.
        vertexBuffer[i].Color[0] = r;
        vertexBuffer[i].Color[1] = g;
        vertexBuffer[i].Color[2] = b;
        vertexBuffer[i].Color[3] = a;

		vertexCount += 1;
	}




//    glBindBuffer(GL_ARRAY_BUFFER, _drawingVBO);
//    CHECK_GL;

    glEnableVertexAttribArray(_positionSlot);
    CHECK_GL;
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    CHECK_GL;
    glEnableVertexAttribArray(_colorSlot);
    CHECK_GL;
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) *3));
    CHECK_GL;
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(Vertex) * count, vertexBuffer);
    CHECK_GL;

    
    
    glUniform1i(_textureSlot, 1);
    CHECK_GL;
    glActiveTexture(GL_TEXTURE1);
    CHECK_GL;
    glBindTexture(GL_TEXTURE_2D, _brushTexture);
    CHECK_GL;
//
	glDrawArrays(GL_POINTS, 0, vertexCount);
    CHECK_GL;
	
    // Store VBO for undo
    if (container && container.data == nil) {
        NSData *data = [NSData dataWithBytes:vertexBuffer length:vertexCount * sizeof(Vertex)] ;
        container.data = data;
    }

    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    CHECK_GL;
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    CHECK_GL;

    if (needRenderVBO) {
        [self renderVBOBuffers];
    }


}

- (void) renderVBOBuffers
{
    NSUInteger i = 0;
    static NSUInteger maxBufferCount = 1025;
    
//    GLuint vbo;
//    glGenBuffers(1, &vbo);
//    CHECK_GL;
//    glBindBuffer(GL_ARRAY_BUFFER, vbo);
//    CHECK_GL;
//    glBufferData(GL_ARRAY_BUFFER, maxBufferCount * sizeof(Vertex), nil, GL_STREAM_DRAW);
//    CHECK_GL;
    
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    CHECK_GL;
    
    if (vertexBuffer == NULL) {
        vertexBuffer = malloc(maxBufferCount * sizeof(Vertex));
    }
    
    for (i = 0; i < [drawingCurves count]; i++) {
        DVDrawingCurve * curve = [drawingCurves objectAtIndex:i];
        
        // set color.
//        CGFloat r,g,b,a;
//        [curve.color getRed:&r green:&g blue:&b alpha:&a];
        
//        glColor4f(r	* kBrushOpacity,
//                  g * kBrushOpacity,
//                  b	* kBrushOpacity,
//                  kBrushOpacity);
        


        
        NSUInteger j = 0;
        for (j = 0; j < [curve.elements count]; j++) {
            DVDrawingElement * elem = [curve.elements objectAtIndex:j];
            NSData * data = elem.data;
            if (data) {
                NSUInteger count = data.length / (sizeof(Vertex));
                
                if (count >= maxBufferCount) {
                    while (count >= maxBufferCount) {
                        vertexMax *= 2;
                    }
                    
                    vertexBuffer = realloc(vertexBuffer, vertexMax * sizeof(Vertex));
                    [self destroyVertexBufferObject];
                    CHECK_GL;
                    [self initializeVertexBufferObject];
                    CHECK_GL;
//                    glDeleteBuffers(1, &vbo);
//                    CHECK_GL;
//                    glGenBuffers(1, &vbo);
//                    CHECK_GL;
//                    glBindBuffer(GL_ARRAY_BUFFER, vbo);
//                    CHECK_GL;
//                    glBufferData(GL_ARRAY_BUFFER, maxBufferCount * sizeof(Vertex), nil, GL_STREAM_DRAW);
//                    CHECK_GL;
                }
                
//                GLuint vbo;
//                glGenBuffers(1, &vbo);
//                CHECK_GL;
//                glBindBuffer(GL_ARRAY_BUFFER, vbo);
//                CHECK_GL;
//                glBufferData(GL_ARRAY_BUFFER, count * sizeof(Vertex), data.bytes, GL_STREAM_DRAW);
//                                CHECK_GL;
                //    GLuint indexBuffer;
                //    glGenBuffers(1, &indexBuffer);
                //    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
                //    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
                
                
                glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                                      sizeof(Vertex), 0);
                CHECK_GL;
                glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                                      sizeof(Vertex), (GLvoid*) (sizeof(float) *3));
                CHECK_GL;
                glBufferSubData(GL_ARRAY_BUFFER, 0, count * sizeof(Vertex), data.bytes);
                CHECK_GL;
                //    GLuint indexBuffer;
                //    glGenBuffers(1, &indexBuffer);
                //    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
                //    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
                
                // Render the vertex array
//                glUniform1i(_textureSlot, 1);
//                                CHECK_GL;
//                glActiveTexture(GL_TEXTURE1);
//                                CHECK_GL;
//                glBindTexture(GL_TEXTURE_2D, _brushTexture);
//                                CHECK_GL;
                //    glEnable(GL_TEXTURE_2D);
                //    glUniform1i(_textureSlot, 1);
                //    glUniform1f(_brushSizeSlot, 22);
                
                //	glVertexPointer(2, GL_FLOAT, 0, vertexBuffer);
                
                glDrawArrays(GL_POINTS, 0, count);
                                CHECK_GL;
//                glVertexPointer(2, GL_FLOAT, 0, vbo.bytes);
//                glDrawArrays(GL_POINTS, 0, count);
            }
        }
        
    }
    
	// Display the buffer
//	glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
//    CHECK_GL;
	[_context presentRenderbuffer:GL_RENDERBUFFER];
    CHECK_GL;
    
    // set color back to pen color.
    CGFloat r,g,b,a;
    [self.penColor getRed:&r green:&g blue:&b alpha:&a];
    
//    glColor4f(r	* kBrushOpacity,
//              g * kBrushOpacity,
//              b	* kBrushOpacity,
//              kBrushOpacity);
    
}



- (void) setupTexture
{
    CGImageRef brushImage;
    size_t width, height;
    // Create a texture from an image
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [UIImage imageNamed:@"Particle.png"].CGImage;
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    _brushWidth = width;
    _brushHeight = height;
    // Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
    // you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
    NSAssert(brushImage, @"brushImage is nil");
    // Make sure the image exists
    if(brushImage) {
//        // Allocate  memory needed for the bitmap context
//        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
//        // Use  the bitmatp creation function provided by the Core Graphics framework.
//        brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
//        // After you create the context, you can draw the  image to the context.
//        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
//        // You don't need the context at this point, so you need to release it to avoid memory leaks.
//        CGContextRelease(brushContext);
//        // Use OpenGL ES to generate a name for the texture.
//        glGenTextures(1, &_brushTexture);
//        // Bind the texture name.
//        glBindTexture(GL_TEXTURE_2D, _brushTexture);
//        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
//        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//        // Specify a 2D texture image, providing the a pointer to the image data in memory
//        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
//        // Release  the image data; it's no longer needed
//        free(brushData);
        [self setTexture:[UIImage imageNamed:@"Particle.png"] forUniform:@"texture"];
                CHECK_GL;
//        glEnable(GL_TEXTURE_2D);
//        CHECK_GL;
    }
    
}


- (void)setTexture:(UIImage*)image forUniform:(NSString*)uniform {
    
    CGSize sizeOfImage = [image size];
    CGFloat scaleOfImage = [image scale];
    CGSize pixelSizeOfImage = CGSizeMake(scaleOfImage * sizeOfImage.width, scaleOfImage * sizeOfImage.height);
    
    //create context
    GLubyte * spriteData = (GLubyte *)malloc(pixelSizeOfImage.width * pixelSizeOfImage.height * 4 * sizeof(GLubyte));
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, pixelSizeOfImage.width, pixelSizeOfImage.height, 8, pixelSizeOfImage.width * 4, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);
    
    //draw image into context
    CGContextDrawImage(spriteContext, CGRectMake(0.0, 0.0, pixelSizeOfImage.width, pixelSizeOfImage.height), image.CGImage);
    
    //get uniform of texture
    GLuint uniformIndex = glGetUniformLocation(_programHandle, [uniform UTF8String]);
    
    //generate texture
    GLuint textureIndex;
    glGenTextures(1, &textureIndex);
    glBindTexture(GL_TEXTURE_2D, textureIndex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    //create texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, pixelSizeOfImage.width, pixelSizeOfImage.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, textureIndex);
    //"send" to shader
    glUniform1i(uniformIndex, 1);
    if ([uniform isEqualToString:@"texture"]) {
        _textureSlot = uniformIndex;
        _brushTexture = textureIndex;
    }
    free(spriteData);
    CGContextRelease(spriteContext);
}

- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
{
    GLfloat r_l = right - left;
    GLfloat t_b = top - bottom;
    GLfloat f_n = far - near;
    GLfloat tx = - (right + left) / (right - left);
    GLfloat ty = - (top + bottom) / (top - bottom);
    GLfloat tz = - (far + near) / (far - near);
    
    matrix[0] = 2.0f / r_l;
    matrix[1] = 0.0f;
    matrix[2] = 0.0f;
    matrix[3] = tx;
    
    matrix[4] = 0.0f;
    matrix[5] = 2.0f / t_b;
    matrix[6] = 0.0f;
    matrix[7] = ty;
    
    matrix[8] = 0.0f;
    matrix[9] = 0.0f;
    matrix[10] = 2.0f / f_n;
    matrix[11] = tz;
    
    matrix[12] = 0.0f;
    matrix[13] = 0.0f;
    matrix[14] = 0.0f;
    matrix[15] = 1.0f;
}

// Handles the start of a touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
//    NSLog(@"DVDrawingView touch began.");
	CGRect				bounds = [self bounds];
    UITouch*	touch = [[event touchesForView:self] anyObject];
	firstTouch = YES;
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
	location = [touch locationInView:self];
	location.y = bounds.size.height - location.y;
    
    
    // start a curve for drawing
    currentDrawingCurve = [[DVDrawingCurve alloc]init];
    currentDrawingCurve.elements = [[NSMutableArray alloc] init];
    DVDrawingElement * elem = [[DVDrawingElement alloc]init];
    elem.position = location;
    [drawingCurves addObject:currentDrawingCurve];

//    dispatch_queue_t drawingCounterQueue = nil;
//    drawingCounterQueue = [[DVQueueService sharedService] getSharedQueue:DVDrawingCounterQueue];
//    
//    dispatch_sync(drawingCounterQueue, ^{
//        self.touchCount++;
//        currentDrawingCurve.count = self.touchCount;
//    });
    
    
//    
    [currentDrawingCurve.elements addObject:elem];
    
    
    // start a curve
    //    currentCurve = [[NSMutableArray alloc]init];
    //    [currentCurve addObject:[NSValue valueWithCGPoint:location]];
}

// Handles the continuation of a touch.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    
	CGRect				bounds = [self bounds];
	UITouch*			touch = [[event touchesForView:self] anyObject];
    
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
	if (firstTouch) {
		firstTouch = NO;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
	} else {
		location = [touch locationInView:self];
	    location.y = bounds.size.height - location.y;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
	}
    
	// Render the stroke
    //    [currentCurve addObject: [NSValue valueWithCGPoint:location]];
    DVDrawingElement * elem = [[DVDrawingElement alloc]init];
    elem.position = location;
    
    
	[self renderLineFromPoint:previousLocation toPoint:location withContainer:elem];
    [currentDrawingCurve.elements addObject:elem];
}

// Handles the end of a touch event when the touch is a tap.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
   	CGRect				bounds = [self bounds];
    UITouch*	touch = [[event touchesForView:self] anyObject];
//    NSLog(@"DVDrawingView touchended. location is %@", touch);
    
    DVDrawingElement * elem = [[DVDrawingElement alloc]init];
    elem.position = location;
    NSLog(@"touch ended at %@", touch);
	if (firstTouch) {
		firstTouch = NO;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
        //        [currentCurve addObject: [NSValue valueWithCGPoint:location]];
        
		[self renderLineFromPoint:previousLocation toPoint:location withContainer:elem];
	}
    
    [currentDrawingCurve.elements addObject:elem];
    //    DVDrawingCurve * curve = [[DVDrawingCurve alloc] init];
    //    curve.elements = currentDrawingCurve;
    currentDrawingCurve.color = self.penColor;

//    NSLog(@"%@", drawingCurves);
    
    
//    if (drawingCurves.count == 4) {
//        [self renderVBOBuffers];
//    }
    
//
//    BOOL isMultiPlayerGame = [[DVGameCenterHelper sharedInstance]isMultiPlayerGame];
//    if (isMultiPlayerGame) {
//        
//        
//        NSMutableDictionary * userInfo = [[NSMutableDictionary alloc]init];
//        [userInfo setObject:currentDrawingCurve forKey:DVDrawingCurveIdentifier];
//        DVGameCenterHelper * gc = [DVGameCenterHelper sharedInstance];
//        
//        [userInfo setObject:gc.currentPlayer.basicPlayer.playerID forKey:DVGamePlayerIDIdentifier];
//        
//        [[NSNotificationCenter defaultCenter] postNotificationName:DVMultiplayerDrawLineNotification object:self userInfo:userInfo];
//    }
    
    //    [curves addObject:currentCurve];
    //    if (self.currentPlayer) {
    //        [self.currentPlayer commitDrawing:currentCurve];
    //    }
    
}

// Handles the end of a touch event.
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	// If appropriate, add code necessary to save the state of the application.
	// This application is not saving state.
}


- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
	// Set the brush color using premultiplied alpha values
    
    self.penColor = [UIColor colorWithRed:red green:green blue:blue alpha:kBrushOpacity];
    
//	glColor4f(red	* kBrushOpacity,
//			  green * kBrushOpacity,
//			  blue	* kBrushOpacity,
//			  kBrushOpacity);
}

- (void)setDebugViewEnabled:(BOOL)enable
{
    glClearColor(0.0f, 0.0f, 1.0f, 0.5f);
}


#if TARGET_IPHONE_SIMULATOR
#define BREAKPOINT __asm__ volatile ("int3");
#else
#define BREAKPOINT __asm__ volatile ("bkpt 1")
#endif


void checkGL(void)
{
    GLenum err;
    if (err = glGetError())
    {
        switch (err)
        {
            case GL_INVALID_ENUM:
                NSLog(@"OPENGL ERROR: GL_INVALID_ENUM");
                BREAKPOINT;
                break;
                
            case GL_INVALID_VALUE:
                NSLog(@"OPENGL ERROR: GL_INVALID_VALUE");
                BREAKPOINT;
                break;
                
            case GL_INVALID_OPERATION:
                NSLog(@"OPENGL ERROR: GL_INVALID_OPERATION");
                BREAKPOINT;
                break;
                
            case GL_OUT_OF_MEMORY:
                NSLog(@"OPENGL ERROR: GL_OUT_OF_MEMORY");
                BREAKPOINT;
                break;
                
            default:
                NSLog(@"OPENGL ERROR: 0x%x", err);
                BREAKPOINT;
                break;
        }
        
    }
}
+ (NSString*) generateFileNameForAsset:(AVAsset*)asset
{
    // rule : [clientName] + [duration] + [generationTimeStamp] + ".mov"
    NSString * clientName = @"DVVideoTempName";
    NSString * duration = @"_UNKNOWN_DURATION";
    NSString * timeStamp = [[NSDate date]description];
    NSString * fileExtension = @".mov";
    
    NSString * val = [NSString stringWithFormat:@"%@%@%@%@", clientName, duration, timeStamp, fileExtension, nil];
    
    return val;
}

- (void)initializeMovieWithOutputSettings:(NSMutableDictionary *)outputSettings;
{
//    isRecording = NO;
    
//    self.enabled = YES;
//    frameData = (GLubyte *) malloc((int)videoSize.width * (int)videoSize.height * 4);
    
    //    frameData = (GLubyte *) calloc(videoSize.width * videoSize.height * 4, sizeof(GLubyte));
    NSError *error = nil;
//    assetWriter = [[AVAssetWriter alloc] init];
    movieURL = [[NSURL alloc] initFileURLWithPath:[OGLView generateFileNameForAsset:nil]];
    fileType = AVFileTypeQuickTimeMovie;
    assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:fileType error:&error];
    if (error != nil)
    {
        NSAssert(error != nil, @"Error: %@", error);
//        if (failureBlock)
//        {
//            failureBlock(error);
//        }
//        else
//        {
//            if(self.delegate && [self.delegate respondsToSelector:@selector(movieRecordingFailedWithError:)])
//            {
//                [self.delegate movieRecordingFailedWithError:error];
//            }
//        }
    }
    
    // Set this to make sure that a functional movie is produced, even if the recording is cut off mid-stream. Only the last second should be lost in that case.
    assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    
    // use default output settings if none specified
    if (outputSettings == nil)
    {
        outputSettings = [[NSMutableDictionary alloc] init];
        [outputSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [outputSettings setObject:[NSNumber numberWithInt:self.frame.size.width] forKey:AVVideoWidthKey];
        [outputSettings setObject:[NSNumber numberWithInt:self.frame.size.height] forKey:AVVideoHeightKey];
    }
    // custom output settings specified
    else
    {
		NSString *videoCodec = [outputSettings objectForKey:AVVideoCodecKey];
		NSNumber *width = [outputSettings objectForKey:AVVideoWidthKey];
		NSNumber *height = [outputSettings objectForKey:AVVideoHeightKey];
		
		NSAssert(videoCodec && width && height, @"OutputSettings is missing required parameters.");
    }
    
    /*
     NSDictionary *videoCleanApertureSettings = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInt:videoSize.width], AVVideoCleanApertureWidthKey,
     [NSNumber numberWithInt:videoSize.height], AVVideoCleanApertureHeightKey,
     [NSNumber numberWithInt:0], AVVideoCleanApertureHorizontalOffsetKey,
     [NSNumber numberWithInt:0], AVVideoCleanApertureVerticalOffsetKey,
     nil];
     
     NSDictionary *videoAspectRatioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInt:3], AVVideoPixelAspectRatioHorizontalSpacingKey,
     [NSNumber numberWithInt:3], AVVideoPixelAspectRatioVerticalSpacingKey,
     nil];
     */
     
     NSMutableDictionary * compressionProperties = [[NSMutableDictionary alloc] init];
//     [compressionProperties setObject:videoCleanApertureSettings forKey:AVVideoCleanApertureKey];
//     [compressionProperties setObject:videoAspectRatioSettings forKey:AVVideoPixelAspectRatioKey];
     [compressionProperties setObject:[NSNumber numberWithInt: 2000000] forKey:AVVideoAverageBitRateKey];
     [compressionProperties setObject:[NSNumber numberWithInt: 16] forKey:AVVideoMaxKeyFrameIntervalKey];
     [compressionProperties setObject:AVVideoProfileLevelH264Main31 forKey:AVVideoProfileLevelKey];
     
     [outputSettings setObject:compressionProperties forKey:AVVideoCompressionPropertiesKey];
     
    
    assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    assetWriterVideoInput.expectsMediaDataInRealTime = NO/*_encodingLiveVideo*/;
    
    // You need to use BGRA for the video in order to get realtime encoding. I use a color-swizzling shader to line up glReadPixels' normal RGBA output with the movie input's BGRA.
//    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
//                                                           [NSNumber numberWithInt:self.frame.size.width], kCVPixelBufferWidthKey,
//                                                           [NSNumber numberWithInt:self.frame.size.height], kCVPixelBufferHeightKey,
//                                                           nil];
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey,
                                                           nil];
    
    assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:assetWriterVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    [assetWriter addInput:assetWriterVideoInput];
}

@end
