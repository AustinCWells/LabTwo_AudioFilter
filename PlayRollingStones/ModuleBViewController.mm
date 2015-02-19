//
//  ModuleBViewController.m
//  AudioLab
//
//  Created by ch484-mac6 on 2/16/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "ModuleBViewController.h"
#import "Novocaine.h"
#import "AudioFileReader.h"
#import "RingBuffer.h"
#import "SMUGraphHelper.h"
#import "SMUFFTHelper.h"


#define kBufferLength 4096

@interface ModuleBViewController ()
@property (strong, nonatomic) IBOutlet UISlider *slider;
@property (strong, nonatomic) IBOutlet UILabel *frequency;
@property (strong, nonatomic) IBOutlet UILabel *gesture;
@property (nonatomic) GraphHelper *graphHelper;
@property (nonatomic) float *audioData;
@property (nonatomic) float *fftMagnitudeBuffer;
@property (nonatomic) float *fftPhaseBuffer;
@property (nonatomic) SMUFFTHelper *fftHelper;
@property (strong, nonatomic) Novocaine *audioManager;
@property ( nonatomic) RingBuffer* ringBufferB;

- (IBAction)sliderChanged:(id)sender;
@end

@implementation ModuleBViewController

-(RingBuffer*)ringBufferB {
    if(!_ringBufferB){
        _ringBufferB = new RingBuffer(kBufferLength,2);
    }
    
    return _ringBufferB;
}

-(GraphHelper*)graphHelper{
    if(!_graphHelper){
        int framesPerSecond = 30;
        int numDataArraysToGraph = 1;
        _graphHelper = new GraphHelper(self,
                                       framesPerSecond,
                                       numDataArraysToGraph,
                                       PlotStyleSeparated);//drawing starts immediately after call
    }
    return _graphHelper;
}

-(float*)audioData{
    if(!_audioData){
        _audioData = (float*)calloc(kBufferLength,sizeof(float));
    }
    
    return _audioData;
}

-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    
    return _audioManager;
}

-(float*)fftPhaseBuffer{
    if(!_fftPhaseBuffer){
        _fftPhaseBuffer  = (float *)calloc(kBufferLength/2,sizeof(float));
    }
    return _fftPhaseBuffer;
}

-(float*)fftMagnitudeBuffer{
    if(!_fftMagnitudeBuffer){
        _fftMagnitudeBuffer = (float *)calloc(kBufferLength/2,sizeof(float));
    }
    return _fftMagnitudeBuffer;
}

-(SMUFFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = new SMUFFTHelper(kBufferLength,kBufferLength,WindowTypeRect);
    }
    return _fftHelper;
}

-(void) viewWillDisappear:(BOOL)animated{
    [self.audioManager pause];
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    self.graphHelper->draw(); // draw the graph
}

-(void)viewWillAppear:(BOOL)animated{
    //overloading this function, call to get functiionality
    [super viewWillAppear:animated];
    
    __block float startingFrequency = 20000;
    __block float phase1 = 0.0;
    __block float samplingRate = self.audioManager.samplingRate;
    [self.audioManager play];
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
         self.ringBufferB->AddNewFloatData(data, numFrames);
     }];
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
            startingFrequency = self.slider.value * 1000.0;
             double phaseIncrement1 = 2*M_PI*startingFrequency/samplingRate;
             double sineWavePeriod = 2*M_PI;
             for (int i=0; i < numFrames; ++i)
             {
                 for(int j=0;j<numChannels;j++)
                     data[i*numChannels+j] = 0.5*sin(phase1);
                 
                 phase1 += phaseIncrement1;
                 if (phase1 >= sineWavePeriod) phase1 -= 2*M_PI;

             }
              }];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.frequency.text = @"15.00 kHz";
    self.slider.maximumValue = 20;
    self.slider.minimumValue = 15;
    
    self.ringBufferB = new RingBuffer(kBufferLength,2);
    
    self.graphHelper->SetBounds(-0.9,0.9,-0.9,0.9); // bottom, top, left, right, full screen==(-1,1,-1,1)

}

//  override the GLKViewController update function, from OpenGLES
- (void)update{
    
    //split into chunck of 20
    // find maximum frequency per chunck
    // populate the array
    
    
    
    // plot the audio
    self.ringBufferB->FetchFreshData2(self.audioData, kBufferLength, 0, 1);
    
    
    //take the FFT
    self.fftHelper->forward(0,self.audioData, self.fftMagnitudeBuffer, self.fftPhaseBuffer);
    
    // plot the FFT
    self.graphHelper->setGraphData(0,self.fftMagnitudeBuffer+1300,kBufferLength/2 - 1400,1); // set graph channel
    

    
    
    self.graphHelper->update(); // update the graph
}


-(void)dealloc{
    
    self.graphHelper->tearDownGL();
    
    free(self.audioData);
    free(self.fftMagnitudeBuffer);
    free(self.fftPhaseBuffer);
    free(self.ringBufferB);
    
    free(self.fftHelper);
    free(self.graphHelper);
    
    self.ringBufferB = nil;
    self.fftHelper  = nil;
    self.audioManager = nil;
    self.graphHelper = nil;
    
    // ARC handles everything else, just clean up what we used c++ for (calloc, malloc, new)
    
}

#pragma mark - status bar
-(BOOL)prefersStatusBarHidden{
    return YES;
}

- (IBAction)sliderChanged:(id)sender {
    self.frequency.text = [NSString stringWithFormat:@"%.002f kHz", self.slider.value];
}
@end
