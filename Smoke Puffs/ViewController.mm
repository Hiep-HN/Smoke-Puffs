//
//  ViewController.m
//  Smoke Puffs
//
//  Created by Matt Stanton on 7/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "UIImage+OpenCV.h"

#import <QuartzCore/QuartzCore.h>

#import "Fluid.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_SAMPLER,
    UNIFORM_XRES,
    UNIFORM_YRES,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

#if 0
// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};
#endif

@interface ViewController () {
  GLuint _program;
  
  GLKMatrix4 _modelViewProjectionMatrix;
  GLKMatrix3 _normalMatrix;
  float _rotation;
  
  GLuint _vertexArray;
  GLuint _vertexBuffer;
  
  int _width;
  int _height;
  
  Fluid* _fluid;
  
  float _dt;
  
  float _ball_x;
  float _ball_y;
  
  GLint sampler;
  GLuint density_texture;
  
  UIView* red_ball;
  UIView* green_ball;
  UIView* goal_left;
  UIView* goal_right;
  UIImageView* soccer_ball;
  int ball_size;
  int soccer_ball_size;
  int goal_height;
  int goal_width;
  int points_left;
  int points_right;
  UILabel* score_label;
  int ball_wait_frames;
  
  BOOL soccer_on;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;

@property (nonatomic, assign) Fluid* fluid;
@property (nonatomic, assign) float dt;

@property (nonatomic, assign) float ball_x;
@property (nonatomic, assign) float ball_y;


- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
- (CGPoint)screenCoordsFromFluidCoords:(CGPoint)pt;
- (CGPoint)fluidCoordsFromScreenCoords:(CGPoint)pt;

-(void)setupSoccer;
-(void)tearDownSoccer;
-(void)pointScored;
@end

@implementation ViewController

@synthesize captureSession = _captureSession;

@synthesize context = _context;
@synthesize effect = _effect;
@synthesize width = _width;
@synthesize height = _height;
@synthesize fluid = _fluid;
@synthesize dt = _dt;
@synthesize ball_x = _ball_x;
@synthesize ball_y = _ball_y;

- (CGPoint)screenCoordsFromFluidCoords:(CGPoint)pt
{
  return CGPointMake(1024.0f / self.width * pt.x,
                     768.0f - 768.0f / self.height * pt.y);
}

- (CGPoint)fluidCoordsFromScreenCoords:(CGPoint)pt
{
  return CGPointMake(self.width / 1024.0f * pt.x,
                     (768.0f - pt.y) * self.height / 768.0f);
}

- (void)pointScored
{
  score_label.text = [NSString stringWithFormat: @"%d : %d", points_left, points_right];
  self.ball_x = self.width / 2.0;
  self.ball_y = self.height / 2.0;
  ball_wait_frames = 30;
  [soccer_ball removeFromSuperview];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
  
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
  
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
  
    self.width = 108;
    self.height = 84;
    self.fluid = new Fluid(self.width, self.height);
    self.dt = 0.25f;
    self.ball_x = self.width * 0.5f;
    self.ball_y = self.height * 0.5f;
    
    
    [self initCapture];
       
    [self setupGL];
    [self.view setMultipleTouchEnabled:YES];
  
  ball_size = 30;
  soccer_ball_size = 40;
        
  red_ball = [[UIView alloc] init];
  [red_ball setBackgroundColor:[UIColor redColor]];
  red_ball.frame = CGRectMake(0, 0, ball_size, ball_size);
  red_ball.layer.cornerRadius = ball_size/2;
  [self.view addSubview:red_ball];
  
  green_ball = [[UIView alloc] init];
  [green_ball setBackgroundColor:[UIColor greenColor]];
  green_ball.frame = CGRectMake(0, 0, ball_size, ball_size);
  green_ball.layer.cornerRadius = ball_size/2;
  [self.view addSubview:green_ball];
  
  soccer_ball = [[UIImageView alloc] initWithImage: [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"soccer_ball" ofType:@"png"]]];
  soccer_ball.frame = CGRectMake(0, 0, soccer_ball_size, soccer_ball_size);
  
  goal_width = 100;
  goal_height = 200;
  
  goal_left = [[UIView alloc] init];
  goal_left.frame = CGRectMake(0, 384-goal_height/2, goal_width, goal_height);
  goal_left.layer.borderWidth = 10.0f;
  goal_left.layer.borderColor = [[UIColor blackColor] CGColor];
  
  
  goal_right = [[UIView alloc] init];
  goal_right.frame = CGRectMake(1024 - goal_width, 384-goal_height/2, goal_width, goal_height);
  goal_right.layer.borderWidth = 10.0f;
  goal_right.layer.borderColor = [[UIColor blackColor] CGColor];
  
  score_label = [ [UILabel alloc ] initWithFrame:CGRectMake(300.0f, 0.0f, 400.0f, 100.0) ];
  score_label.textAlignment =  UITextAlignmentCenter;
  score_label.textColor = [UIColor blackColor];
  score_label.backgroundColor = [UIColor clearColor];
  score_label.font = [UIFont fontWithName:@"Arial Rounded MT Bold" size:(48.0)];
  
  ball_wait_frames = -1;
  
  soccer_on = NO;
  
}


- (void)setupSoccer {
  [self.view addSubview:soccer_ball];
  [self.view addSubview:goal_left];
  [self.view addSubview:goal_right];
  
  points_left = 0;
  points_right = 0;
  ball_wait_frames = -1;
  self.ball_x = self.width / 2.0;
  self.ball_y = self.height / 2.0;
  soccer_ball.center = [self screenCoordsFromFluidCoords:CGPointMake(self.ball_x, self.ball_y)];
  [self.view addSubview:score_label];
  score_label.text = [NSString stringWithFormat: @"%d : %d", points_left, points_right];
  soccer_on = YES;
}

- (void)tearDownSoccer {
  [soccer_ball removeFromSuperview];
  [goal_left removeFromSuperview];
  [goal_right removeFromSuperview];
  [score_label removeFromSuperview];
  
  soccer_on = NO;
}

- (void)initCapture {
	/*We setup the input*/

    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDeviceInput *captureInput = nil;
    for (AVCaptureDevice *device in devices) {
        // Get the front or the back camera
        if (device.position == AVCaptureDevicePositionFront) {
            captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
            break;
        }
    }
    
    
	//AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput 
	//									  deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] 
	//									  error:nil];
    
    

    


	/*We setupt the output*/
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	/*While a frame is processes in -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
	 If you don't want this behaviour set the property to NO */
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
	/*We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
	 in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
	 In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
	 we are not able to process more than 10 frames per second.*/
	//captureOutput.minFrameDuration = CMTimeMake(1, 10);
	
	/*We create a serial queue to handle the processing of our frames*/
	dispatch_queue_t queue;
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings]; 
	/*And we create a capture session*/
	self.captureSession = [[AVCaptureSession alloc] init];
	/*We add input and output*/
  if (captureInput != nil) {
    [self.captureSession addInput:captureInput];
  }
	[self.captureSession addOutput:captureOutput];
    /*We use medium quality, ont the iPhone 4 this demo would be laging too much, the conversion in UIImage and CGImage demands too much ressources for a 720p resolution.*/
    [self.captureSession setSessionPreset:AVCaptureSessionPresetMedium];	
	[self.captureSession startRunning];
	
}


#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{ 
	/*We create an autorelease pool because as we are not in the main_queue our code is
	 not executed in the main thread. So we have to create an autorelease pool for the thread we are in*/
	
	//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);  
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext); 
	
    /*We release some components*/
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the custom layer. All the display stuff must be done in the main thread because
	 UIKit is no thread safe, and as we are not in the main thread (remember we didn't use the main_queue)
	 we use performSelectorOnMainThread to call our CALayer and tell it to display the CGImage.*/
	///[self.customLayer performSelectorOnMainThread:@selector(setContents:) withObject: (id) newImage waitUntilDone:YES];
	
	/*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly).
	 Same thing as for the CALayer we are not in the main thread so ...*/
	UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];

    
    [self findBlobs:image];
    
	/*We relase the CGImageRef*/
	CGImageRelease(newImage);
	
	//[self.imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	//[pool drain];
}

// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
    // Getting CGImage from UIImage
    CGImageRef imageRef = image.CGImage;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // Creating temporal IplImage for drawing
    IplImage *iplimage = cvCreateImage(
                                       cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4
                                       );
    // Creating CGContext for temporal IplImage
    CGContextRef contextRef = CGBitmapContextCreate(
                                                    iplimage->imageData, iplimage->width, iplimage->height,
                                                    iplimage->depth, iplimage->widthStep,
                                                    colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault
                                                    );
    // Drawing CGImage to CGContext
    CGContextDrawImage(
                       contextRef,
                       CGRectMake(0, 0, image.size.width, image.size.height),
                       imageRef
                       );
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    // Creating result IplImage
    IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplimage, ret, CV_RGBA2BGR);
    cvReleaseImage(&iplimage);
    return ret;
}



-(void)findBlobs:(UIImage *)image {
    
    IplImage *img = [self CreateIplImageFromUIImage:image];
    
    _lastFrame = img;
    
    const int detect_res_x = 50; 
    const int detect_res_y = 50;
    cv::resize(_lastFrame, _lastFrame, cv::Size(detect_res_y,detect_res_x));
                
    int greens_found = 0;
    int greens_x = 0;
    int greens_y = 0;
           
    int blues_found = 0;
    int blues_x = 0;
    int blues_y = 0;
    for(int x = 0;x<_lastFrame.cols;x++){
        for(int y=0;y<_lastFrame.rows;y++) {
            int rVal = _lastFrame.at<cv::Vec3b>(x,y)[0];
            int gVal = _lastFrame.at<cv::Vec3b>(x,y)[1];
            int bVal = _lastFrame.at<cv::Vec3b>(x,y)[2];
                
            if(gVal>100 && rVal<90 && bVal<90){
                greens_found++;
                greens_x = greens_x + x;
                greens_y = greens_y + y;
            }
                        
            if(gVal<100 && rVal<100 && bVal>200){
                blues_found++;
                blues_x = blues_x + x;
                blues_y = blues_y + y;
            }
        }                    
    }    
    
  const int detect_threshold = 0;
    if(greens_found>detect_threshold){
        int x = greens_x/greens_found;
        int y = greens_y/greens_found;       
        green_x = x * (768/detect_res_x);
        green_y = y * (1024/detect_res_y);        
        green_x = 768 - green_x;        
    }
    
    if(blues_found>detect_threshold){
        int x = blues_x/blues_found;
        int y = blues_y/blues_found;        
        red_x = x * (768/detect_res_y);
        red_y = y * (1024/detect_res_x);               
        red_x = 768 - red_x;
    }
    
    cvReleaseImage(&img);
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
  delete self.fluid;
	self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return interfaceOrientation == UIInterfaceOrientationLandscapeRight;
  //  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
  //      return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
  //  } else {
  //      return YES;
  //  }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    self.effect = [[GLKBaseEffect alloc] init];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods


int green_x = 768/2, green_y = 1024/2;
int previous_green_x = 768/2, previous_green_y = 1024/2;
int red_x, red_y;
int previous_red_x = 768/2, previous_red_y = 1024/2;

- (void)update
{
  self.fluid->Step(self.dt);
  
  if (soccer_on) {
    if (ball_wait_frames > 0) {
      --ball_wait_frames;
    } else {
      
      if (ball_wait_frames == 0) {
        --ball_wait_frames;
        [self.view addSubview:soccer_ball];
      }
      
      self.fluid->AdvectPoint(self.dt, self.ball_x, self.ball_y, &_ball_x, &_ball_y);
      float ball_r = soccer_ball_size / 2.0f * self.width / 1024.0f;
      self.ball_x = std::max(ball_r, self.ball_x);
      self.ball_x = std::min(self.width - ball_r, self.ball_x);
      self.ball_y = std::max(ball_r, self.ball_y);
      self.ball_y = std::min(self.height - ball_r, self.ball_y);
      
      float ball_screen_r = soccer_ball_size / 2.0f - 4.0f;
      CGPoint ball_screen = [self screenCoordsFromFluidCoords:CGPointMake(self.ball_x, self.ball_y)];
      if (ball_screen.y < (384.0f + goal_height/2 + ball_screen_r) && ball_screen.y > (384.0f - goal_height/2 - ball_screen_r)) {
        if (ball_screen.x < (ball_screen_r + goal_width)) {
          ++points_right;
          [self pointScored];
        }
        if (ball_screen.x > (1024.0f - ball_screen_r - goal_width)) {
          ++points_left;
          [self pointScored];
        }
      }
        soccer_ball.center = ball_screen;
    }
  }


    

  green_x = (previous_green_x + green_x) /2;
  green_y = (previous_green_y + green_y) /2;
  
  red_x = (previous_red_x + red_x)/2;
  red_y = (previous_red_y + red_y)/2;
  red_ball.center = CGPointMake(red_y , red_x);
  green_ball.center = CGPointMake(green_y , green_x);

    
  
   
    CGPoint green_pt = [self fluidCoordsFromScreenCoords:CGPointMake(green_y, green_x)];
    CGPoint previous_green_pt = [self fluidCoordsFromScreenCoords:CGPointMake(previous_green_y, previous_green_x)];
        
    self.fluid->AddImpulse( green_pt.x,
                           green_pt.y,
                           green_pt.x - previous_green_pt.x,
                           green_pt.y - previous_green_pt.y);
    
    
    CGPoint red_pt = [self fluidCoordsFromScreenCoords:CGPointMake(red_y, red_x)];
    CGPoint previous_red_pt = [self fluidCoordsFromScreenCoords:CGPointMake(previous_red_y, previous_red_x)];
    
    self.fluid->AddImpulse( red_pt.x,
                           red_pt.y,
                           red_pt.x - previous_red_pt.x,
                           red_pt.y - previous_red_pt.y);


    
    /* 
    self.fluid->AddImpulse(green_y, green_y/self.height,
                           1,
                           1);
     */
    
 
    /*
    int _ry = (1024/2) - (red_y / (1024/45));
    _ry =  (1024/45) + _ry;
    
    self.fluid->AddImpulse(red_x / (768/60),
                           _ry,
                           ((previous_red_x - red_x)/(768/60))*2,
                           -((red_y - previous_red_y)/(1024/45))*2);
    
 */
    
    
    previous_green_x = green_x;
    previous_green_y = green_y;

    previous_red_x = red_x;
    previous_red_y = red_y;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
  
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  
  glClearColor(0.3f, 0.3f, 0.6f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  self.effect.transform.projectionMatrix = GLKMatrix4MakeOrtho(0, self.width, 0, self.height, 1, -1);
  self.effect.transform.modelviewMatrix = GLKMatrix4Identity;
  
  // Use the program object
  glUseProgram ( _program );
  
  float drawrect[] = {
    0.0, 0.0, 0.0, 0.0,
    self.width, 0.0, 1.0, 0.0,
    0.0, self.height, 0.0, 1.0,
    self.width, self.height, 1.0, 1.0
  };
  GLushort indices[] = {0, 1, 2, 2, 3, 1};
  
  // Load the vertex position
  glVertexAttribPointer ( GLKVertexAttribPosition, 2, GL_FLOAT, 
                         GL_FALSE, 4 * sizeof(GLfloat), drawrect );
  // Load the texture coordinate
  glVertexAttribPointer ( GLKVertexAttribTexCoord0, 2, GL_FLOAT,
                         GL_FALSE, 4 * sizeof(GLfloat), &drawrect[2] );
  
  glEnableVertexAttribArray ( GLKVertexAttribPosition );
  glEnableVertexAttribArray (GLKVertexAttribTexCoord0 );
  
  // Bind the texture
  glActiveTexture ( GL_TEXTURE0 );
  glBindTexture ( GL_TEXTURE_2D, density_texture );
  std::vector<float> density;
  self.fluid->GetDensities(&density);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, self.width, self.height, GL_LUMINANCE, GL_FLOAT, &density[0]);
  
  // Set the sampler texture unit to 0
  glUniform1i ( uniforms[UNIFORM_SAMPLER], 0 );
  glUniform1f ( uniforms[UNIFORM_XRES], self.width );
  glUniform1f ( uniforms[UNIFORM_YRES], self.height );
  glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, GL_FALSE, self.effect.transform.projectionMatrix.m);
  
  glDrawElements ( GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, indices );
  glDisableVertexAttribArray(GLKVertexAttribPosition);
  glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
  
  // Render the object with GLKit
//  [self.effect prepareToDraw];
//  std::vector<float> lines;
//  self.fluid->GetLines(&lines, 3.0);
//  
//  glEnableVertexAttribArray(GLKVertexAttribPosition);
//  glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, 0, &(lines[0]));
//  glDrawArrays(GL_LINES, 0, lines.size()/2);
//  glDisableVertexAttribArray(GLKVertexAttribPosition);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "a_texCoord");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_SAMPLER] = glGetUniformLocation(_program, "s_texture");
  uniforms[UNIFORM_XRES] = glGetUniformLocation(_program, "xres");
  uniforms[UNIFORM_YRES] = glGetUniformLocation(_program, "yres");
  
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
  
  // Generate a texture object
  glGenTextures ( 1, &density_texture );
  
  // Bind the texture object
  glBindTexture ( GL_TEXTURE_2D, density_texture );
  
  // Set the filtering mode
  glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
  glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  
  std::vector<float> density;
  self.fluid->GetDensities(&density);
  // Load the texture
  glTexImage2D ( GL_TEXTURE_2D, 0, GL_LUMINANCE, self.width, self.height, 0, GL_LUMINANCE, GL_FLOAT, &density[0] );
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

//-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {  
//  // Remove old red circles on screen
////  NSArray *subviews = [self.view subviews];
////  for (UIView *view in subviews) {
////    [view removeFromSuperview];
////  }
//
//  // Enumerate over all the touches and draw a red dot on the screen where the touches were
//  [touches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
//    // Get a single touch and it's location
//    UITouch *touch = obj;
//    CGPoint touchPoint = [touch locationInView:self.view];
//    CGPoint previousTouchPoint = [touch previousLocationInView:self.view];
//    
//    // Draw a red circle where the touch occurred
////    UIView *touchView = [[UIView alloc] init];
////    [touchView setBackgroundColor:[UIColor redColor]];
////    touchView.frame = CGRectMake(touchPoint.x, touchPoint.y, 30, 30);
////    touchView.layer.cornerRadius = 15;
////    [self.view addSubview:touchView];
////    
////    UIView *previousTouchView = [[UIView alloc] init];
////    [previousTouchView setBackgroundColor:[UIColor blueColor]];
////    previousTouchView.frame = CGRectMake(previousTouchPoint.x, previousTouchPoint.y, 30, 30);
////    previousTouchView.layer.cornerRadius = 15;
////    [self.view addSubview:previousTouchView];
//    
//    self.fluid->AddImpulse(touchPoint.x * self.width / 1024,
//                           self.height - touchPoint.y * self.height / 768,
//                           (touchPoint.x - previousTouchPoint.x) * self.width / 1024,
//                           -(touchPoint.y - previousTouchPoint.y) * self.height / 768);
//    //NSLog(@"%g %g %g %g\n", touchPoint.x, touchPoint.y, previousTouchPoint.x, previousTouchPoint.y);
//  }];
//}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  if ([touches anyObject] != nil) {
    if (soccer_on) {
      [self tearDownSoccer];
    } else {
      [self setupSoccer];
    }
  }
}


@end
