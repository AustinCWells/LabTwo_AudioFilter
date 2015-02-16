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
- (IBAction)sliderChanged:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *frequency;

@end

@implementation ModuleBViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.frequency.text = @"15.00 kHz";
    self.slider.maximumValue = 20;
    self.slider.minimumValue = 15;
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

- (IBAction)sliderChanged:(id)sender {
    self.frequency.text = [NSString stringWithFormat:@"%.002f kHz", self.slider.value];
}
@end
