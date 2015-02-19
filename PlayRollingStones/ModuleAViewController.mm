//
//  ModuleAViewController.m
//  AudioLab
//
//  Created by ch484-mac6 on 2/16/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "ModuleAViewController.h"
#import "ViewController.h"
#import "Novocaine.h"
#import "AudioFileReader.h"
#import "RingBuffer.h"
#import "SMUGraphHelper.h"
#import "SMUFFTHelper.h"

#define kBufferLength 4096
#define kEquilizeLength 20
#define intensityThreshold 2
#define deltaOfFrequency 5.3833007813

@interface ModuleAViewController ()
@property (strong, nonatomic) IBOutlet UIButton *recordButton;
@property (strong, nonatomic) IBOutlet UILabel *freq1;
@property (strong, nonatomic) IBOutlet UILabel *freq2;

@property (strong, nonatomic) Novocaine *audioManager;
@property (nonatomic) float *audioData;
@property (nonatomic) SMUFFTHelper *fftHelper;
@property (nonatomic) float *fftMagnitudeBuffer;
@property (nonatomic) float *fftPhaseBuffer;
@property (nonatomic) float *fftEquilizerBuffer;
@property (nonatomic) GraphHelper *graphHelper;
@property ( nonatomic) RingBuffer* ringBuffer;


-(int)getHighestFrequencyFromBuffer:(float*)fftMagBuffer;

@end

@implementation ModuleAViewController

#pragma mark - loading and appear
- (void)viewDidLoad
{
    [super viewDidLoad];
    // start animating the graph
    
    

    self.graphHelper->SetBounds(-0.9,0.9,-0.9,0.9); // bottom, top, left, right, full screen==(-1,1,-1,1)
    
    
}

-(void) viewWillDisappear:(BOOL)animated{
    [self.audioManager pause];
}

-(RingBuffer*)ringBuffer{
    if(!_ringBuffer){
        _ringBuffer = new RingBuffer(kBufferLength,2);
    }
    
    return _ringBuffer;
}

-(float*)fftEquilizerBuffer{
    if(!_fftEquilizerBuffer){
        _fftEquilizerBuffer = (float *)calloc(kEquilizeLength,sizeof(float));
    }
    return _fftEquilizerBuffer;
}

-(GraphHelper*)graphHelper{
    if(!_graphHelper){
        int framesPerSecond = 30;
        int numDataArraysToGraph = 3;
        _graphHelper = new GraphHelper(self,
                                       framesPerSecond,
                                       numDataArraysToGraph,
                                       PlotStyleSeparated);//drawing starts immediately after call
    }
    return _graphHelper;
}

-(SMUFFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = new SMUFFTHelper(kBufferLength,kBufferLength,WindowTypeRect);
    }
    return _fftHelper;
}

-(float*)fftMagnitudeBuffer{
    if(!_fftMagnitudeBuffer){
        _fftMagnitudeBuffer = (float *)calloc(kBufferLength/2,sizeof(float));
    }
    return _fftMagnitudeBuffer;
}

-(float*)fftPhaseBuffer{
    if(!_fftPhaseBuffer){
        _fftPhaseBuffer  = (float *)calloc(kBufferLength/2,sizeof(float));
    }
    return _fftPhaseBuffer;
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

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.audioManager play];
    
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
             self.ringBuffer->AddNewFloatData(data, numFrames);
     }];
    
}

-(void) viewDidDisappear:(BOOL)animated{
    // stop opengl from running
    //self.graphHelper->tearDownGL();
}

-(void)dealloc{
    
    self.graphHelper->tearDownGL();
    
    free(self.audioData);
    free(self.fftMagnitudeBuffer);
    free(self.fftPhaseBuffer);
    free(self.ringBuffer);
    free(self.graphHelper);
    free(self.fftHelper);
    
    self.ringBuffer = nil;
    self.fftHelper  = nil;
    self.audioManager = nil;
    self.graphHelper = nil;
    
    // ARC handles everything else, just clean up what we used c++ for (calloc, malloc, new)
    
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    self.graphHelper->draw(); // draw the graph
}

//  override the GLKViewController update function, from OpenGLES
- (void)update{
    
    //split into chunck of 20
    // find maximum frequency per chunck
    // populate the array
    
    
    
    // plot the audio
    self.ringBuffer->FetchFreshData2(self.audioData, kBufferLength, 0, 1);
    
    
    
    self.graphHelper->setGraphData(0,self.audioData,kBufferLength); // set graph channel
    
    //take the FFT
    self.fftHelper->forward(0,self.audioData, self.fftMagnitudeBuffer, self.fftPhaseBuffer);
    
    // plot the FFT
    self.graphHelper->setGraphData(1,self.fftMagnitudeBuffer,kBufferLength/2,sqrt(kBufferLength)); // set graph channel
    
    
    
    
    // fetch the maxium magnitude for each 20 bits of data
    /*int incrementAmount = kBufferLength/kEquilizeLength/2;
    for(int i = 0; i < (kBufferLength/2-incrementAmount); i+= incrementAmount){
        //NSLog(@"%f", self.fftMagnitudeBuffer[i/incrementAmount]);
        float maxVal = 0.0;
        vDSP_maxv(self.fftMagnitudeBuffer+i, 1, &maxVal, incrementAmount);
        self.fftEquilizerBuffer[i/incrementAmount] = maxVal;
    }*/
    
    float frequency1 = [self getHighestFrequencyFromBuffer: self.fftMagnitudeBuffer];
    self.freq1.text = [NSString stringWithFormat: @"%iHz", (int)frequency1];

    
    int frequency2 = [self getHighestFrequencyFromBuffer: self.fftMagnitudeBuffer];
    //NSLog(@"%f", indexOfMax*5.3833007813*2);
    self.freq2.text = [NSString stringWithFormat: @"%iHz", frequency2];
    
    
    
    // plot the Equilizer
    self.graphHelper->setGraphData(2,self.fftEquilizerBuffer,kEquilizeLength,sqrt(kBufferLength)); // set graph channel
    
    
    
    
    self.graphHelper->update(); // update the graph
}

-(int)getHighestFrequencyFromBuffer:(float*)fftMagBuffer{
    int max = 0;
    int indexOfMax = 0;
    for(int i = 0; i < kBufferLength; i++){
        float curMag = self.fftMagnitudeBuffer[i];
        if(curMag > max && curMag > intensityThreshold){
            max = self.fftMagnitudeBuffer[i];
            indexOfMax = i;
        }
    }
    
    int removeWindowStart = indexOfMax - 9;
    if (removeWindowStart < 0)
        removeWindowStart = 0;
    for(int i = 0; i < 19; i++)
        self.fftMagnitudeBuffer[removeWindowStart++] = 0;
    
    
    
    return (int) indexOfMax*deltaOfFrequency*2;
}

#pragma mark - status bar
-(BOOL)prefersStatusBarHidden{
    return YES;
}



@end
