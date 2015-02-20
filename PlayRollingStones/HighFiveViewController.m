//
//  HighFiveViewController.m
//  PlayRollingStones
//
//  Created by ch484-mac6 on 2/20/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "HighFiveViewController.h"

@interface HighFiveViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@end

@implementation HighFiveViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    self.imageView.image = [UIImage imageNamed:@"hand.png"];
    self.scrollView.contentSize = self.imageView.image.size;
    self.imageView.frame = CGRectMake(0, 0, self.imageView.image.size.width, self.imageView.image.size.height);
    self.scrollView.maximumZoomScale = 5;
    self.scrollView.minimumZoomScale = .5;
    self.scrollView.zoomScale = 1;
    self.scrollView.clipsToBounds = YES;
    self.scrollView.delegate = self;
}


@end
