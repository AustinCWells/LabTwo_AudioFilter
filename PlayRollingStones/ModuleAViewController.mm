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
#define kIntensityThreshold 5
#define kDeltaOfFrequency 44100.0/4096.0/2
#define kMovingAverageBufferSize 5

@interface ModuleAViewController ()
@property (strong, nonatomic) IBOutlet UILabel *freq1;
@property (strong, nonatomic) IBOutlet UILabel *freq2;
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UILabel *note1;

@property (strong, nonatomic) Novocaine *audioManager;
@property (nonatomic) float *audioData;
@property (nonatomic) SMUFFTHelper *fftHelper;
@property (nonatomic) float *fftMagnitudeBuffer;
@property (nonatomic) float *fftPhaseBuffer;
@property (nonatomic) float *fftMagnitudeBufferCopy;
@property (nonatomic) GraphHelper *graphHelper;
@property (nonatomic) RingBuffer* ringBuffer;
@property (nonatomic) int *movingAverageBufferA;
@property (nonatomic) int *movingAverageBufferB;
@property (nonatomic) BOOL captureSound;
@property (nonatomic) BOOL displayNotes;
@property (strong, nonatomic) NSDictionary * frequencyLookUp;
- (IBAction)displayNotes:(UISwitch *)sender;
@property (weak, nonatomic) IBOutlet UISwitch *captureSwitch;

- (IBAction)frequencyCaptured:(UISwitch *)sender;
-(void)displayFirstNoteBeingPlayed:(int) firstFrequency;
-(int)addToMovingAverageA:(int) newMeasurement;
-(int)addToMovingAverageB:(int) newMeasurement;
-(void)getTwoHighestFrequencies:(int*) firstFrequency secondFrequency:(int*)secondFrequency magnitudeBufferCopy:(float*)buffer;

@end

@implementation ModuleAViewController

#pragma mark - loading and appear
- (void)viewDidLoad{
    [super viewDidLoad];
    // start animating the graph
    
    
    
    self.graphHelper->SetBounds(-0.9,0.9,-0.9,0.9); // bottom, top, left, right, full screen==(-1,1,-1,1)
}

-(void) viewWillDisappear:(BOOL)animated{
    [self.audioManager pause];
    
}


-(NSDictionary*)frequencyLookUp{
    if(!_frequencyLookUp){
        _frequencyLookUp= @{
                            
                            [NSNumber numberWithInt:1800]:@"B", //1875
                            [NSNumber numberWithInt:1698]:@"D", //1701
                            [NSNumber numberWithInt:1600]:@"B", // 1691
                            [NSNumber numberWithInt:1570]:@"G", //1570
                            [NSNumber numberWithInt:1560]:@"A♯/B♭", //1570
                            [NSNumber numberWithInt:1500]:@"A", //1550
                            [NSNumber numberWithInt:1480]:@"F♯/G♭", //1480
                            [NSNumber numberWithInt:1470]:@"D", // 1475 D
                            [NSNumber numberWithInt:1440]:@"G♯/A♭", //1464
                            [NSNumber numberWithInt:1420]:@"D", //1429
                            [NSNumber numberWithInt:1380]:@"F", // 1399
                            [NSNumber numberWithInt:1350]:@"G", //1378
                            [NSNumber numberWithInt:1337]:@"G", // 1338
                            [NSNumber numberWithInt:1300]:@"F♯/G♭", // 1336
                            [NSNumber numberWithInt:1250]:@"G", // 1298
                            [NSNumber numberWithInt:1200]:@"C♯/D♭", // 1248
                            [NSNumber numberWithInt:1189]:@"F", //1191
                            [NSNumber numberWithInt:1175]:@"C", //1187
                            [NSNumber numberWithInt:1170]:@"A♯/B♭", //1170
                            [NSNumber numberWithInt:1128]:@"E", //1160 E
                            [NSNumber numberWithInt:1115]:@"B", //116
                            [NSNumber numberWithInt:1109]:@"C♯/D♭", //1110
                            [NSNumber numberWithInt:1090]:@"D", //1108
                            [NSNumber numberWithInt:1085]:@"D♯/E♭", //1089
                            [NSNumber numberWithInt:1050]:@"G", //1058
                            [NSNumber numberWithInt:1025]:@"C", //1048
                            [NSNumber numberWithInt:1018]:@"F♯/G♭", //1020
                            [NSNumber numberWithInt:1007]:@"D", // 1008
                            [NSNumber numberWithInt:1002]:@"A", // 1002
                            [NSNumber numberWithInt:999]:@"F♯/G♭", // 1000
                            [NSNumber numberWithInt:985]:@"B", //990
                            [NSNumber numberWithInt:980]:@"D♯/E♭", //980 ish
                            [NSNumber numberWithInt:973]:@"C♯/D♭", //974
                            [NSNumber numberWithInt:972]:@"D", //972
                            [NSNumber numberWithInt:965]:@"F♯/G♭", //966
                            [NSNumber numberWithInt:940]:@"F", // 961
                            [NSNumber numberWithInt:930]:@"A♯/B♭", //936
                            [NSNumber numberWithInt:923]:@"F♯/G♭", // 925
                            [NSNumber numberWithInt:920]:@"D♯/E♭", //920
                            [NSNumber numberWithInt:900]:@"C", // 916
                            [NSNumber numberWithInt:880]:@"A or D", // 882 A D
                            [NSNumber numberWithInt:872]:@"F", // 872
                            [NSNumber numberWithInt:870]:@"C♯/D♭", // 870
                            [NSNumber numberWithInt:869]:@"B", //869
                            [NSNumber numberWithInt:839]:@"A♯/B♭", //841
                            [NSNumber numberWithInt:831]:@"C♯/D♭", //831
                            [NSNumber numberWithInt:829]:@"G♯/A♭ or E", //829 G♯/A♭
                            [NSNumber numberWithInt:825]:@"E", //827
                            [NSNumber numberWithInt:800]:@"A♯/B♭", //819
                            [NSNumber numberWithInt:780]:@"G or C", // 786
                            [NSNumber numberWithInt:777]:@"D", //778
                            [NSNumber numberWithInt:773]:@"D♯/E♭", //776
                            [NSNumber numberWithInt:750]:@"A", //772
                            [NSNumber numberWithInt:740]:@"F♯/G♭ or B", //742
                            [NSNumber numberWithInt:720]:@"D",// 730
                            [NSNumber numberWithInt:640]:@"E", //658
                            [NSNumber numberWithInt:630]:@"C", //632 kind of
                            [NSNumber numberWithInt:620]:@"D♯/E♭", // 624
                            [NSNumber numberWithInt:580]:@"D",// 592
                            [NSNumber numberWithInt:540]:@"C♯/D♭", // 552
                            [NSNumber numberWithInt:520]:@"C", // 552
                            [NSNumber numberWithInt:465]:@"B", // 495
                            [NSNumber numberWithInt:450]:@"A♯/B♭", //462
                            [NSNumber numberWithInt:430]:@"A", //441
                            [NSNumber numberWithInt:410]:@"G♯/A♭", //419
                            [NSNumber numberWithInt:380]:@"G",//390
                            [NSNumber numberWithInt:360]:@"F♯/G♭", //368
                            [NSNumber numberWithInt:335]:@"F", //348
                            [NSNumber numberWithInt:325]:@"E", //333
                            [NSNumber numberWithInt:300]:@"D♯/E♭", //312
                            
                            
                            };
    }
    return _frequencyLookUp;
}

- (IBAction)displayNotes:(UISwitch *)sender {
    self.displayNotes = sender.isOn;
    if(sender.isOn){
        self.captureSound = true;
        self.note1.text = @"N/A";
        [self.captureSwitch setOn:NO animated:YES];
        [self.captureSwitch setEnabled:NO];
    } else {
        self.captureSound = false;
        [self.captureSwitch setEnabled:YES];
    };
}


-(int*)movingAverageBufferA{
    if(!_movingAverageBufferA)
        _movingAverageBufferA = (int *)calloc(kMovingAverageBufferSize,sizeof(int));
    return _movingAverageBufferA;
}

-(int*)movingAverageBufferB{
    if(!_movingAverageBufferB)
        _movingAverageBufferB = (int *)calloc(kMovingAverageBufferSize,sizeof(int));
    return _movingAverageBufferB;
}

-(RingBuffer*)ringBuffer{
    if(!_ringBuffer){
        _ringBuffer = new RingBuffer(kBufferLength,2);
    }
    
    return _ringBuffer;
}

-(float*)fftMagnitudeBufferCopy{
    if(!_fftMagnitudeBufferCopy){
        _fftMagnitudeBufferCopy = (float *)calloc(kBufferLength/2,sizeof(float));
    }
    return _fftMagnitudeBufferCopy;
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

-(IBAction)frequencyCaptured:(UISwitch *)sender {
    self.captureSound = sender.isOn;
    return;
}

-(int)addToMovingAverageA:(int) newMeasurement{
    if (self.captureSound  && newMeasurement < 100){
        int lastMeasurementSum = 0;
        for(int i = 0; i < kMovingAverageBufferSize; i++)
            lastMeasurementSum += self.movingAverageBufferA[i];
        return lastMeasurementSum / kMovingAverageBufferSize;
    }
    
    int sum = 0;
    for(int i = 1; i < kMovingAverageBufferSize; i++){
        self.movingAverageBufferA[i-1] = self.movingAverageBufferA[i];
        sum += self.movingAverageBufferA[i-1];
    }
    self.movingAverageBufferA[kMovingAverageBufferSize-1] = newMeasurement;
    sum += newMeasurement;
    return sum / kMovingAverageBufferSize;
    
}

-(int)addToMovingAverageB:(int) newMeasurement{
    if (self.captureSound && newMeasurement < 100){
        int lastMeasurementSum = 0;
        for(int i = 0; i < kMovingAverageBufferSize; i++)
            lastMeasurementSum += self.movingAverageBufferB[i];
        return lastMeasurementSum / kMovingAverageBufferSize;
    }
    int sum = 0;
    for(int i = 1; i < kMovingAverageBufferSize; i++){
        self.movingAverageBufferB[i-1] = self.movingAverageBufferB[i];
        sum += self.movingAverageBufferB[i-1];
    }
    self.movingAverageBufferB[kMovingAverageBufferSize-1] = newMeasurement;
    sum += newMeasurement;
    return sum / kMovingAverageBufferSize;
    
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
    
    // get the audio
    self.ringBuffer->FetchFreshData2(self.audioData, kBufferLength, 0, 1);
    //take the FFT
    self.fftHelper->forward(0,self.audioData, self.fftMagnitudeBuffer, self.fftPhaseBuffer);
    // plot the FFT
    self.graphHelper->setGraphData(0,self.fftMagnitudeBuffer,kBufferLength/2,sqrt(kBufferLength)); // set graph channel
    
    
    
    int frequency1 = 0;
    int frequency2 = 0;
    for(int i = 0; i < kBufferLength/2; i++)
        self.fftMagnitudeBufferCopy[i] = self.fftMagnitudeBuffer[i];
    [self getTwoHighestFrequencies: &frequency1 secondFrequency:&frequency2 magnitudeBufferCopy:self.fftMagnitudeBufferCopy];
    frequency1 = [self addToMovingAverageA: frequency1];
    frequency2 = [self addToMovingAverageB: frequency2];
    if(frequency1 < 50)
        self.freq1.text = [NSString stringWithFormat: @"increase volume"];
    else
        self.freq1.text = [NSString stringWithFormat: @"%iHz", frequency1];
    if(frequency2 < 50)
        self.freq2.text = [NSString stringWithFormat: @"increase volume"];
    else
        self.freq2.text = [NSString stringWithFormat: @"%iHz", frequency2];
    
    if (self.displayNotes)
        [self displayFirstNoteBeingPlayed:frequency1];
    
    float colorIntensity1 = (frequency1/20000.0+0.30);
    float colorIntensity2 = (frequency2/20000.0+0.30);
    self.freq1.textColor = [UIColor colorWithRed:colorIntensity1 green:colorIntensity1 blue:colorIntensity1 alpha:1];
    self.freq2.textColor = [UIColor colorWithRed:colorIntensity2 green:colorIntensity2 blue:colorIntensity2 alpha:1];
    
    
    self.graphHelper->update(); // update the graph
}

-(void)displayFirstNoteBeingPlayed:(int) firstFrequency{
    NSArray *keys = self.frequencyLookUp.allKeys;
    while(![keys containsObject:[NSNumber numberWithInteger:firstFrequency]]) {
        if(firstFrequency < 100)
            return;
        firstFrequency--;
    }
    self.note1.text = [self.frequencyLookUp objectForKey:[NSNumber numberWithInteger:firstFrequency]];
    return;
}

-(void)getTwoHighestFrequencies:(int *)firstFrequency secondFrequency:(int *)secondFrequency magnitudeBufferCopy:(float * )buffer{
    int max = 0;
    int indexOfMax = 0;
    int multiplier = 1;
    if (self.displayNotes)
        multiplier = 10;
    // search for largest frequency
    for(int i = 0; i < kBufferLength/2; i++){
        float curMag = buffer[i];
        if(curMag > max && curMag > kIntensityThreshold*multiplier){
            max = buffer[i];
            indexOfMax = i;
        }
    }
    
    *firstFrequency = (int) (indexOfMax*kDeltaOfFrequency*2);
    
    // remove largest frequency  from array
    int removeWindowStart = indexOfMax - 8;
    if (removeWindowStart < 0)
        removeWindowStart = 0;
    for(int i = 0; i < 17; i++)
        buffer[removeWindowStart + i] = 0.0;
    
    
    // search for second largest frequency
    max = 0;
    indexOfMax = 0;
    for(int i = 0; i < kBufferLength/2; i++){
        float curMag = buffer[i];
        if(curMag > max && curMag > kIntensityThreshold*multiplier){
            max = buffer[i];
            indexOfMax = i;
        }
    }
    
    *secondFrequency = (int) (indexOfMax*kDeltaOfFrequency*2);
    return;
    
    
    
}

#pragma mark - status bar
-(BOOL)prefersStatusBarHidden{
    return YES;
}



@end
