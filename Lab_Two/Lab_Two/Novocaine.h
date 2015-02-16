// Copyright (c) 2012 Alex Wiltschko
// Updated for iOS7 Eric Larson, 2013
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVAudioSession.h>

#include <Block.h>


#ifdef __cplusplus
extern "C" {
#endif

    void CheckError(OSStatus error, const char *operation);
//{
//    if (error == noErr) return;
//    
//    char str[20];
//    // see if it appears to be a 4-char-code
//    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
//    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
//        str[0] = str[5] = '\'';
//        str[6] = '\0';
//    } else
//        // no, format it as an integer
//        sprintf(str, "%d", (int)error);
//    
//    fprintf(stderr, "Error: %s (%s)\n", operation, str);
//    
//    exit(1);
//}

    
OSStatus inputCallback (void						*inRefCon,
						AudioUnitRenderActionFlags	* ioActionFlags,
						const AudioTimeStamp 		* inTimeStamp,
						UInt32						inOutputBusNumber,
						UInt32						inNumberFrames,
						AudioBufferList				* ioData);

OSStatus renderCallback (void						*inRefCon,
                         AudioUnitRenderActionFlags	* ioActionFlags,
                         const AudioTimeStamp 		* inTimeStamp,
                         UInt32						inOutputBusNumber,
                         UInt32						inNumberFrames,
                         AudioBufferList				* ioData);


void sessionPropertyListener(void *                  inClientData,
							 AudioSessionPropertyID  inID,
							 UInt32                  inDataSize,
							 const void *            inData);



void sessionInterruptionListener(void *inClientData, UInt32 inInterruption);

#ifdef __cplusplus
}
#endif

typedef void (^OutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);
typedef void (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@interface Novocaine : NSObject <UIAlertViewDelegate>
{    
	// Audio Handling
	AudioUnit inputUnit;
    AudioUnit outputUnit;
    AudioBufferList *inputBuffer;
    
	// Session Properties
	BOOL inputAvailable;
	NSString *inputRoute;
	UInt32 numInputChannels;
	UInt32 numOutputChannels;
    Float64 samplingRate;
    BOOL isInterleaved;
    UInt32 numBytesPerSample;
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
	
	// Audio Processing
    OutputBlock outputBlock;
    InputBlock inputBlock;
    
	float *inData;
    float *outData;
	
	BOOL playing;
    // BOOL playThroughEnabled;
    
    
}

@property AudioUnit inputUnit;
@property AudioUnit outputUnit;
@property AudioBufferList *inputBuffer;
@property (nonatomic, copy) OutputBlock outputBlock;
@property (nonatomic, copy) InputBlock inputBlock;
@property BOOL inputAvailable;
@property (nonatomic, retain) NSString *inputRoute;
@property UInt32 numInputChannels;
@property UInt32 numOutputChannels;
@property Float64 samplingRate;
@property BOOL isInterleaved;
@property BOOL isSetUp;
@property UInt32 numBytesPerSample;
@property AudioStreamBasicDescription inputFormat;
@property AudioStreamBasicDescription outputFormat;

// @property BOOL playThroughEnabled;
@property BOOL playing;
@property float *inData;
@property float *outData;


// Singleton methods
+ (Novocaine *) audioManager;


// Audio Unit methods
- (void)play;
- (void)pause;
- (void)setupAudio;
- (void)teardownAudio;
- (void)ifAudioInputIsAvailableThenSetupAudioSession;

- (void)checkSessionProperties;
- (void)checkAudioSource;


@end
