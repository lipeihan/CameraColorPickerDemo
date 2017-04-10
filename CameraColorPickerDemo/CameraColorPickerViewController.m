//
//  ViewController.m
//  CameraColorPickerDemo
//
//  Created by pierce on 16/3/1.
//  Copyright © 2016年 pierce. All rights reserved.
//

#import "CameraColorPickerViewController.h"
#import <AVFoundation/AVFoundation.h>


#define kMainScreenWidth [UIScreen mainScreen].bounds.size.width
#define kMainScreenHeight  [UIScreen mainScreen].bounds.size.height

@interface CameraColorPickerViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong, nonatomic) IBOutlet UIView *colorView;
@property (strong, nonatomic) IBOutlet UIView *preViewVIew;
@property (strong, nonatomic) IBOutlet UIView *bottomView;
@property (strong, nonatomic) IBOutlet UIView *frameView;

//AVFoundation

@property (nonatomic) dispatch_queue_t sessionQueue;
/**
 *  AVCaptureSession对象来执行输入设备和输出设备之间的数据传递
 */
@property (nonatomic, strong) AVCaptureSession* session;
/**
 *  输入设备
 */
@property (nonatomic, strong) AVCaptureDeviceInput* videoInput;
/**
 *  照片输出流
 */
@property (nonatomic, strong) AVCaptureVideoDataOutput* stillImageOutput;
/**
 *  预览图层
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer* previewLayer;

@end

@implementation CameraColorPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.frameView.layer.borderWidth = 2;
    self.frameView.layer.borderColor = [UIColor redColor].CGColor;
    [self initAVCaptureSession];
}
- (IBAction)clickGetColorAction:(UIButton *)sender {
}


- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    
    if (self.session) {
        
        [self.session startRunning];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:YES];
    
    if (self.session) {
        
        [self.session stopRunning];
    }
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark private method
- (void)initAVCaptureSession{
    
    self.session = [[AVCaptureSession alloc] init];
    
    [self.session setSessionPreset:AVCaptureSessionPreset640x480];
    
    NSError *error;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    self.stillImageOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [self.stillImageOutput setVideoSettings:rgbOutputSettings];
    [self.stillImageOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    
    self.sessionQueue = dispatch_queue_create("myQueue", NULL);
    [self.stillImageOutput setSampleBufferDelegate:self queue:self.sessionQueue];
    
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
    
    //初始化预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    NSLog(@"%f",kMainScreenWidth);
    self.previewLayer.frame = CGRectMake(0, 0,kMainScreenWidth, kMainScreenHeight - 64);
    self.preViewVIew.layer.masksToBounds = YES;
    [self.preViewVIew.layer addSublayer:self.previewLayer];
    
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    UIColor *color = [self imageFromSampleBuffer:sampleBuffer];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.colorView setBackgroundColor:color];
    });
}



// Create a UIImage from sample buffer data
- (UIColor *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CGImageRef subImage =  CGImageCreateWithImageInRect(quartzImage, CGRectMake(width / 2 - height / 4, height / 4, height / 2, height / 2));
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:subImage];
    // Release the Quartz image
    CGImageRelease(quartzImage);
    CGImageRelease(subImage);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return [self allColor:image];
}


- (UIColor*)allColor:(UIImage*)image{
    
    int bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
    
    //第一步 先把图片缩小 加快计算速度. 但越小结果误差可能越大
    CGSize thumbSize = CGSizeMake(40, 40);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 thumbSize.width,
                                                 thumbSize.height,
                                                 8,//bits per component
                                                 thumbSize.width*4,
                                                 colorSpace,
                                                 bitmapInfo);
    
    CGRect drawRect = CGRectMake(0, 0, thumbSize.width, thumbSize.height);
    CGContextDrawImage(context, drawRect, image.CGImage);
    
    CGColorSpaceRelease(colorSpace);
    
    
    //第二步 取每个点的像素值
    unsigned char* data = CGBitmapContextGetData (context);
    
    if (data == NULL) return nil;
    int sumRed = 0;
    int sumGreen = 0;
    int sumBlue = 0;
    
    for (int x=0; x<thumbSize.width; x++) {
        for (int y=0; y<thumbSize.height; y++) {
            
            int offset = 4*(x*y);
            sumRed += data[offset];
            sumGreen += data[offset+1];
            sumBlue += data[offset+2];
        }
    }
    CGContextRelease(context);
    int count = thumbSize.width * thumbSize.height;
    
    return [UIColor colorWithRed:((sumRed / count) / 255.0f) green:((sumGreen / count) / 255.0f) blue:((sumBlue / count) / 255.0f) alpha:1.0f];
}

@end
