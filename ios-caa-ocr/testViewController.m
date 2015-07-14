//
//  testViewController.m
//  ios-caa-ocr
//
//  Created by Carter Chang on 7/15/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "testViewController.h"

@interface testViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *sourceImageView;
@property (weak, nonatomic) IBOutlet UIImageView *targetImageView;
@property (weak, nonatomic) IBOutlet UIView *targetView;

@end

@implementation testViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    
    
    UIImage *sourceImg = [UIImage imageNamed:@"eng.png"];
    self.sourceImageView.image = sourceImg;
    
    
    
    CGRect frameRect = self.targetView.frame;
    CGRect superRect = self.targetView.superview.frame;
    
    NSLog(@"frame x=%f", frameRect.origin.x);
    NSLog(@"super x= %f",  superRect.origin.x);
    
    NSLog(@"frame y=%f", frameRect.origin.y);
    NSLog(@"super y= %f",  superRect.origin.y);
    
    
    NSLog(@"frame w=%f", frameRect.size.width);
    NSLog(@"super w= %f",  superRect.size.width);
    
    NSLog(@"frame h=%f", frameRect.size.height);
    NSLog(@"super h= %f",  superRect.size.height);
    CGFloat scale;
    CGRect rect;
    CGFloat offset;
    
    if (sourceImg.size.width / sourceImg.size.height > 1) {
        scale = sourceImg.size.width /  self.sourceImageView.frame.size.width;
    }else {
        scale = sourceImg.size.height /  self.sourceImageView.frame.size.height;
        offset = sourceImg.size.width * (1/scale) /2;
        rect = CGRectMake(
                          (frameRect.origin.x + offset) * scale,
                          (frameRect.origin.y) * scale,
                          frameRect.size.width * scale,
                          frameRect.size.height * scale
                          );
        
    }


    
    CGImageRef imageRef = CGImageCreateWithImageInRect([sourceImg CGImage], rect);
    UIImage *targetImg = [UIImage imageWithCGImage:imageRef ];
    
    CGImageRelease(imageRef);
    
    
    self.targetImageView.image = targetImg ;
    
    
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
