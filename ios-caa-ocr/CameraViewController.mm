//
//  CameraViewController.m
//  ios-caa-ocr
//
//  Created by Carter Chang on 7/14/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "CameraViewController.h"
#import <opencv2/videoio/cap_ios.h>
#import <AVFoundation/AVCaptureOutput.h>
#import "CVWrapper.h"
#import <TesseractOCR/TesseractOCR.h>

using namespace cv;

@interface CameraViewController () <CvVideoCameraDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImageView *cameraView;
@property (weak, nonatomic) IBOutlet UIImageView *photoView;
@property (retain, nonatomic) CvVideoCamera* videoCamera;
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //[self performImageRecognition:[UIImage imageNamed:@"eng.png"]];
    
    [self cameraSetup];
    NSLog(@"Main thread: %@", [NSThread currentThread]);
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:self.imageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    //self.videoCamera.grayscale = NO;
    self.videoCamera.grayscaleMode = NO;
    
     self.videoCamera.delegate = self;
}

- (UIImage *)cropImage:(UIImage *)image to:(CGRect)cropRect andScaleTo:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGImageRef subImage = CGImageCreateWithImageInRect([image CGImage], cropRect);
    
    CGRect myRect = CGRectMake(0.0f, 0.0f, size.width, size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextTranslateCTM(context, 0.0f, -size.height);
    CGContextDrawImage(context, myRect, subImage);
    UIImage* croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(subImage);
    
    //ROTATE LEFT 90 DEGREES
    UIImage * LandscapeImage = croppedImage;
    UIImage * PortraitImage = [[UIImage alloc] initWithCGImage: LandscapeImage.CGImage
                                                         scale: 1.0
                                                   orientation: UIImageOrientationRight];
    
    return PortraitImage;
}

- (IBAction)takePhoto:(id)sender {
    AVCaptureConnection *videoConnnection = nil;
    
    for(AVCaptureConnection *connection in self.stillImageOutput.connections)
    {
        for(AVCaptureInputPort *port in [connection inputPorts])
        {
            if([[port mediaType] isEqual:AVMediaTypeVideo])
            {
                videoConnnection = connection;
                break;
            }
        }
        if(videoConnnection)
        {
            break;
        }
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if(imageDataSampleBuffer != NULL){
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            
            //note:
            //(image.size.height-image.size.width)/2
            //is to account for the borders at the top and bottom of the not yet cropped image
            int barSize = (image.size.height-image.size.width)/2;
            image = [self cropImage:image to:CGRectMake(barSize,0, image.size.width, image.size.height) andScaleTo:CGSizeMake(640, 640)];
            self.photoView.image = image;
            
            [self performImageRecognition:image];
            
        }
    }];

}

- (void) cameraSetup {
    NSArray * devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    NSError *error;
    self.session =[[AVCaptureSession alloc] init];
    
    for ( AVCaptureDevice * device in devices )
    {
        if ( AVCaptureDevicePositionFront == [ device position ] )
        {
            // We asked for the front camera and got the front camera, now keep a pointer to it:
            frontCamera = device;
        }
        else if ( AVCaptureDevicePositionBack == [ device position ] )
        {
            // We asked for the back camera and here it is:
            backCamera = device;
        }
    }
    
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
    if ([self.session canAddInput:deviceInput]) {
        [self.session addInput:deviceInput];
    }

    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    self.previewLayer.session = self.session;
    self.previewLayer.frame = self.cameraView.bounds;
    [self.cameraView.layer addSublayer:self.previewLayer];
    
    // StillImage output
//    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
//    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
//    [self.stillImageOutput setOutputSettings:outputSettings];
//    [self.session addOutput:self.stillImageOutput];
//    
    
    
    
    // VideoDataOutput output
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                       [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
 
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    [self.session addOutput:videoDataOutput];
    
    
    [self.session startRunning];
}


- (void) performImageRecognition:(UIImage*)image{
    
    NSLog(@"Recognition thread: %@", [NSThread currentThread]);
    
    UIImage *bwImage = [image g8_blackAndWhite];
     G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"eng"];
    
    //G8RecognitionOperation *operation = [[G8RecognitionOperation alloc]initWithLanguage:@"eng"];
    tesseract.engineMode = G8OCREngineModeTesseractCubeCombined;
    tesseract.maximumRecognitionTime = 3.0;
    tesseract.image = bwImage;
    [tesseract recognize];
    NSString *recognizedText = tesseract.recognizedText;
    NSLog(@"%@", recognizedText);
    
    
   self.previewLayer.connection.enabled = YES;

}

//-(UIImage*) rotateImage:(UIImage*)image degree:(CGFloat)degree {
//    //CGFloat radiansToDegrees
//}


- (UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, (degrees * M_PI / 180));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


-(UIImage *)rotateImage:(UIImage *)image degree:(CGFloat)degree{
    
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.transform = CGAffineTransformMakeRotation(0);
    CGSize rotatedSize = imageView.frame.size;
    
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(bitmap, rotatedSize.width / 2.0, rotatedSize.height / 2.0);
    CGContextRotateCTM(bitmap, 0);
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-image.size.width / 2, -image.size.height / 2, image.size.width, image.size.height), image.CGImage);
    
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();
    return rotatedImage;
}

-(UIImage*) scaleImage:(UIImage*)image maxDimension:(CGFloat)maxDimension {
    
    CGSize scaledSize = CGSizeMake(maxDimension,maxDimension);
    CGFloat scaleFactor;
    
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    
    if (w>h) {
        scaleFactor = h/w;
        scaledSize.width = maxDimension;
        scaledSize.height = scaledSize.height*scaleFactor;
    }else {
        scaleFactor = w/h;
        scaledSize.height = maxDimension;
        scaledSize.width = scaledSize.width*scaleFactor;
    }
    UIGraphicsBeginImageContext(scaledSize);
    [image drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    NSLog(@"imageFromSampleBuffer: called");
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
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}


- ( void ) captureOutput: ( AVCaptureOutput * ) captureOutput
   didOutputSampleBuffer: ( CMSampleBufferRef ) sampleBuffer
          fromConnection: ( AVCaptureConnection * ) connection
{
    
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    UIImage *img =  [CVWrapper imageFromSampleBuffer:sampleBuffer];
    //UIImage *img = [self imageFromSampleBuffer:sampleBuffer];
    
    
    if (img.size.height != 0) {
        //[self.previewLayer removeFromSuperlayer];
        UIImage *scaledImage = [self imageRotatedByDegrees:[self scaleImage:img maxDimension:640] deg:0];
        
        //UIImage *cropImage = [self cropImage:scaledImage to:CGRectMake(0, 0, 320, 40) andScaleTo:CGSizeMake(320, 40)];
       //[self performImageRecognition:scaledImage];
        
        //[self.session stopRunning];
       // self.previewLayer.connection.enabled = NO;
     
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.photoView.image = scaledImage;
            [self.view setNeedsDisplay];
            //[self.photoView bringSubviewToFront:self.cameraView];
        });
        //UIImage *scaledImage = rotateImage(scaleImage(img, maxDimension: 640), degrees: 0)
    }
}

#pragma mark - Protocol CvVideoCameraDelegate

#ifdef __cplusplus
- (void)processImage:(Mat&)image;
{
    Mat image_copy;
    cvtColor(image, image_copy, CV_BGRA2BGR);
    
//    // invert image
//    bitwise_not(image_copy, image_copy);
//    cvtColor(image_copy, image, CV_BGR2BGRA);
}
#endif


- (IBAction)actionStart:(id)sender {
     [self.videoCamera start];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
