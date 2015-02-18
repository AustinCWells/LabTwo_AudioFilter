//
//  ModuleAViewController.m
//  AudioLab
//
//  Created by ch484-mac6 on 2/16/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "ModuleAViewController.h"

@interface ModuleAViewController ()
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UILabel *freq1;
@property (weak, nonatomic) IBOutlet UILabel *freq2;

@end

@implementation ModuleAViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.freq1.text = @"0kHz";
    self.freq2.text = @"0kHz";
}



@end
