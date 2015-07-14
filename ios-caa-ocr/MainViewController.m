//
//  MainViewController.m
//  ios-caa-ocr
//
//  Created by Carter Chang on 7/14/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "MainViewController.h"
#import <AVFoundation/AVCaptureOutput.h>
#import "CVWrapper.h"
#import <TesseractOCR/TesseractOCR.h>

@interface MainViewController () <G8TesseractDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *cameraImageView;
@property (weak, nonatomic) IBOutlet UIView *targetView;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;
@property (weak, nonatomic) IBOutlet UIImageView *debugImageView;

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (assign, nonatomic) CGPoint startPanLoc;
@property (assign, nonatomic) CGFloat baseScaleX;
@property (assign, nonatomic) CGFloat baseScaleY;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation MainViewController


- (IBAction)onCameraPan:(UIPanGestureRecognizer *)sender {
    CGPoint loc = [sender locationInView:self.cameraImageView];
    if(sender.state == UIGestureRecognizerStateBegan){
        self.startPanLoc = loc;
        
        self.baseScaleX = self.targetView.transform.a;
        self.baseScaleY = self.targetView.transform.d;
    }else if(sender.state == UIGestureRecognizerStateChanged){

        CGFloat scalex = (loc.x - self.startPanLoc.x)/50;
        CGFloat scaley = (loc.y - self.startPanLoc.y)/50;
        
        CGFloat cscalex = MAX(self.baseScaleX+scalex, 0.3);
        CGFloat cscaley = MAX(self.baseScaleY+scaley, 0.3);
        
        cscalex = MIN(cscalex, 2);
        cscaley = MIN(cscaley, 2.5);
        
        self.targetView.transform = CGAffineTransformMakeScale(cscalex, cscaley);
    }else if(sender.state == UIGestureRecognizerStateEnded){
      

    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self cameraSetup];
    self.operationQueue = [[NSOperationQueue alloc] init];
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
    self.previewLayer.frame = self.cameraImageView.bounds;
    [self.cameraImageView.layer addSublayer:self.previewLayer];
    
    // StillImage output
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    
//    NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:
//                                       [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];

    
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    [self.session addOutput:self.stillImageOutput];

    [self.session startRunning];
}

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

-(UIImage*) scaleImage:(UIImage*)image maxDimension:(CGFloat)maxDimension {
    
    CGSize scaledSize = CGSizeMake(maxDimension,maxDimension);
    CGFloat scaleFactor;
    
    double w = image.size.width;
    double h = image.size.height;
    
    if (w>h) {
        scaleFactor = h/w;
        scaledSize.width = maxDimension;
        scaledSize.height = scaledSize.height*scaleFactor;
    }else {
        scaleFactor = w/h;
        scaledSize.height = maxDimension;
        scaledSize.width = scaledSize.height*scaleFactor;
    }
    UIGraphicsBeginImageContext(scaledSize);
    [image drawInRect:CGRectMake(0, -125, scaledSize.width-40, scaledSize.height-70)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

- (void) turnOnCamera {
    [self.cameraImageView.layer addSublayer:self.previewLayer];
}

- (void) turnOffCamera {
    [self.previewLayer removeFromSuperlayer];
}


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

- (void)imageProcessing:(void(^)(UIImage *image))completion {
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
    
    videoConnnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if(imageDataSampleBuffer != NULL){
            
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *img = [UIImage imageWithData:imageData];

            //UIImage *img = [self imageFromSampleBuffer:imageDataSampleBuffer];
            
            [self turnOffCamera];
            
            if (img.size.height != 0) {
                UIImage *scaledImage = [self imageRotatedByDegrees:[self scaleImage:img maxDimension:640] deg:0];
                
                
                self.cameraImageView.image = scaledImage;
                
                [NSTimer scheduledTimerWithTimeInterval:2.0
                                                 target:self
                                               selector:@selector(turnOnCamera)
                                               userInfo:nil
                                                repeats:NO];
                
                
                //--- Crop image by targetView
                CGRect frameRect = self.targetView.frame;
                
                CGRect rect = CGRectMake(
                                         frameRect.origin.x,
                                         frameRect.origin.y,
                                         frameRect.size.width,
                                         frameRect.size.height
                                         );
                
                CGImageRef imageRef = CGImageCreateWithImageInRect([scaledImage CGImage], rect);
                UIImage *cropedImg = [UIImage imageWithCGImage:imageRef ];
                
                CGImageRelease(imageRef);

                // Apply openCV effect
                UIImage *cvImage = [CVWrapper UIImageGrayFromUIImage:cropedImg];
                completion(cvImage);
                //----
                
            }
            
        }
    }];
}

- (IBAction)onOCR:(id)sender {
    [self imageProcessing:^(UIImage *image) {
        self.debugImageView.image = image ;
        [self performImageRecognition:image];
    }];
}

- (IBAction)onCameraViewTap:(UITapGestureRecognizer *)sender {
    [self imageProcessing:^(UIImage *image) {
        self.debugImageView.image = image ;
        [self performImageRecognition:image];
    }];
}

- (void) performImageRecognition:(UIImage*)image{
    UIImage *bwImage = [image g8_blackAndWhite];
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc]initWithLanguage:@"eng"];
    operation.tesseract.maximumRecognitionTime = 30.0;
    //operation.tesseract.engineMode = G8OCREngineModeTesseractCubeCombined;
    operation.tesseract.pageSegmentationMode = G8PageSegmentationModeSingleLine;
    
    operation.delegate = self;
    operation.tesseract.image = bwImage;
    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        // Fetch the recognized text
        NSString *recognizedText = tesseract.recognizedText;
        self.resultLabel.text = recognizedText;
        [G8Tesseract clearCache];
    };
    [self.operationQueue addOperation:operation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Image picker
- (IBAction)selectPhoto:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self presentViewController:picker animated:YES completion:NULL];
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
    self.cameraImageView.image = chosenImage;
    [self turnOffCamera];
    [picker dismissViewControllerAnimated:YES completion:NULL];
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
