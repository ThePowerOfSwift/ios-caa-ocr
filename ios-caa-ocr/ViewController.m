//
//  ViewController.m
//  ios-caa-ocr
//
//  Created by Carter Chang on 7/13/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
        self.operationQueue = [[NSOperationQueue alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recognizeImage:(id)sender {
    [self recognizeImageWithTesseract:[UIImage imageNamed:@"eng.png"]];
    //[self recognizeImageWithTesseract2];
}

- (UIImage *)imageWithImage:(UIImage *)image convertToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *destImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return destImage;
}

- (void)recognizeImageWithTesseract:(UIImage*) image {
  
    
    UIImage *bwImage = [image g8_blackAndWhite];
    
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc]initWithLanguage:@"eng"];
    //operation.tesseract.engineMode = G8OCREngineModeTesseractOnly;
    //operation.tesseract.engineMode = G8OCREngineModeTesseractCubeCombined;
    
    //operation.tesseract.pageSegmentationMode = G8PageSegmentationModeAutoOnly;
    //operation.tesseract.pageSegmentationMode = G8PageSegmentationModeAuto;

    operation.tesseract.maximumRecognitionTime = 30.0;
    
    
    operation.delegate = self;
    operation.tesseract.image = bwImage;
    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        // Fetch the recognized text
        NSString *recognizedText = tesseract.recognizedText;
        
        // Remove the animated progress activity indicator
        //[self.activityIndicator stopAnimating];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OCR Result"
                                                        message:recognizedText
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
    };
    [self.operationQueue addOperation:operation];
    [G8Tesseract clearCache];
}

- (IBAction)openCamera:(id)sender
{
    UIImagePickerController *imgPicker = [UIImagePickerController new];
    imgPicker.delegate = self;
    
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        imgPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:imgPicker animated:YES completion:nil];
    }
}

- (IBAction)clearCache:(id)sender
{
    [G8Tesseract clearCache];
}

- (void)recognizeImageWithTesseract2
{
    // Languages are used for recognition (e.g. eng, ita, etc.). Tesseract engine
    // will search for the .traineddata language file in the tessdata directory.
    // For example, specifying "eng+ita" will search for "eng.traineddata" and
    // "ita.traineddata". Cube engine will search for "eng.cube.*" files.
    // See https://code.google.com/p/tesseract-ocr/downloads/list.
    
    // Create your G8Tesseract object using the initWithLanguage method:
    G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"chi_tra"];
    
    // Optionaly: You could specify engine to recognize with.
    // G8OCREngineModeTesseractOnly by default. It provides more features and faster
    // than Cube engine. See G8Constants.h for more information.
    //tesseract.engineMode = G8OCREngineModeTesseractOnly;
    
    // Set up the delegate to receive Tesseract's callbacks.
    // self should respond to TesseractDelegate and implement a
    // "- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract"
    // method to receive a callback to decide whether or not to interrupt
    // Tesseract before it finishes a recognition.
    tesseract.delegate = self;
    
    // Optional: Limit the character set Tesseract should try to recognize from
    // tesseract.charWhitelist = @"0123456789";
    
    // This is wrapper for common Tesseract variable kG8ParamTesseditCharWhitelist:
    // [tesseract setVariableValue:@"0123456789" forKey:kG8ParamTesseditCharBlacklist];
    // See G8TesseractParameters.h for a complete list of Tesseract variables
    
    // Optional: Limit the character set Tesseract should not try to recognize from
    //tesseract.charBlacklist = @"OoZzBbSs";
    
    // Specify the image Tesseract should recognize on
    tesseract.image = [[UIImage imageNamed:@"cht.png"] g8_blackAndWhite];
    
    // Optional: Limit the area of the image Tesseract should recognize on to a rectangle
    //tesseract.rect = CGRectMake(20, 20, 100, 100);
    
    // Optional: Limit recognition time with a few seconds
    // tesseract.maximumRecognitionTime = 2.0;
    
    // Start the recognition
    [tesseract recognize];
    
    // Retrieve the recognized text
    NSLog(@"%@", [tesseract recognizedText]);
    
    // You could retrieve more information about recognized text with that methods:
    NSArray *characterBoxes = [tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelSymbol];
    NSArray *paragraphs = [tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelParagraph];
    NSArray *characterChoices = tesseract.characterChoices;
    UIImage *imageWithBlocks = [tesseract imageWithBlocks:characterBoxes drawText:YES thresholded:NO];
    self.imgView.image = imageWithBlocks;
    
    
    NSString *recognizedText = tesseract.recognizedText;
    
    // Remove the animated progress activity indicator
    //[self.activityIndicator stopAnimating];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OCR Result"
                                                    message:recognizedText
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    NSLog(@"progress: %lu", (unsigned long)tesseract.progress);
}

- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    return NO;  // return YES, if you need to interrupt tesseract before it finishes
}


#pragma mark - UIImagePickerController Delegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self recognizeImageWithTesseract:image];
}


@end
