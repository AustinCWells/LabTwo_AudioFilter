//
//  ModuleBViewController.m
//  AudioLab
//
//  Created by ch484-mac6 on 2/16/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "ModuleBViewController.h"

@interface ModuleBViewController ()
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *frequency;
@property (weak, nonatomic) IBOutlet UILabel *gesture;
- (IBAction)sliderChanged:(id)sender;
@end

@implementation ModuleBViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.frequency.text = @"15.00 kHz";
    self.slider.maximumValue = 20;
    self.slider.minimumValue = 15;
}


- (IBAction)sliderChanged:(id)sender {
    self.frequency.text = [NSString stringWithFormat:@"%.002f kHz", self.slider.value];
}
@end
