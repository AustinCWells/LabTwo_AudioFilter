//
//  ViewController.m
//  PlayRollingStones
//
//  Created by Eric Larson on 2/5/14.
//  Copyright (c) 2014 Eric Larson. All rights reserved.
//

#import "ViewController.h"
#import "Novocaine.h"
#import "AudioFileReader.h"
#import "RingBuffer.h"
#import "SMUGraphHelper.h"
#import "SMUFFTHelper.h"


#define kBufferLength 4096
#define kEquilizeLength 20

@interface ViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (nonatomic) float *audioData;
@property (nonatomic) SMUFFTHelper *fftHelper;
@property (nonatomic) float *fftMagnitudeBuffer;
@property (nonatomic) float *fftPhaseBuffer;
@property (nonatomic) float *fftEquilizerBuffer;
@property (nonatomic) GraphHelper *graphHelper;
//@property (nonatomic) AudioFileReader *fileReader;
@end

@implementation ViewController



RingBuffer *ringBuffer;





#pragma mark - loading and appear
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    ringBuffer = new RingBuffer(kBufferLength,2);
    // start animating the graph

    
    self.graphHelper->SetBounds(-0.9,0.9,-0.9,0.9); // bottom, top, left, right, full screen==(-1,1,-1,1)
    
}

-(void) viewWillDisappear:(BOOL)animated{
    [self.audioManager pause];
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
         if(ringBuffer!=nil)
             ringBuffer->AddNewFloatData(data, numFrames);
     }];
    
//    __block float frequency = 261.0; //starting frequency
//    __block float phase = 0.0;
//    __block float samplingRate = audioManager.samplingRate;
//    
//    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
//     {
//         
//         double phaseIncrement = 2*M_PI*frequency/samplingRate;
//         double repeatMax = 2*M_PI;
//         for (int i=0; i < numFrames; ++i)
//         {
//             for(int j=0;j<numChannels;j++){
//                 data[i*numChannels+j] = 0.8*sin(phase);
//                 
//             }
//             phase += phaseIncrement;
//             
//             if(phase>repeatMax)
//                 phase -= repeatMax;
//         }
//
//         
//     }];

}

#pragma mark - unloading and dealloc
-(void) viewDidDisappear:(BOOL)animated{
    // stop opengl from running
    self.graphHelper->tearDownGL();
}

-(void)dealloc{
    self.graphHelper->tearDownGL();
    
    free(self.audioData);
    free(self.fftMagnitudeBuffer);
    free(self.fftPhaseBuffer);
    
    delete self.fftHelper;
    delete ringBuffer;
    delete self.graphHelper;
    
    ringBuffer = nil;
    self.fftHelper  = nil;
    self.audioManager = nil;
    self.graphHelper = nil;
    
    // ARC handles everything else, just clean up what we used c++ for (calloc, malloc, new)
    
}

#pragma mark - OpenGL and Update functions
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
    ringBuffer->FetchFreshData2(self.audioData, kBufferLength, 0, 1);
    
    
    
    self.graphHelper->setGraphData(0,self.audioData,kBufferLength); // set graph channel
    
    //take the FFT
    self.fftHelper->forward(0,self.audioData, self.fftMagnitudeBuffer, self.fftPhaseBuffer);
    
    // plot the FFT
    self.graphHelper->setGraphData(1,self.fftMagnitudeBuffer,kBufferLength/8,sqrt(kBufferLength)); // set graph channel
    
    // fetch the maxium magnitude for each 20 bits of data
    int incrementAmount = kBufferLength/20/2;
    for(int i = 0; i < (kBufferLength/2-incrementAmount); i+= incrementAmount){
        float maxVal = 0.0;
        vDSP_maxv(self.fftMagnitudeBuffer+i, 1, &maxVal, incrementAmount);
        self.fftEquilizerBuffer[i/incrementAmount] = maxVal;
    }
    
    // plot the Equilizer
    self.graphHelper->setGraphData(2,self.fftEquilizerBuffer,kEquilizeLength,sqrt(kBufferLength)); // set graph channel
    

    
    
    self.graphHelper->update(); // update the graph
}

#pragma mark - status bar
-(BOOL)prefersStatusBarHidden{
    return YES;
}

@end
