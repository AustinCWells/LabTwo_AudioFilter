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
//
// TODO:
// Switching mic and speaker on/off
//
// HOUSEKEEPING AND NICE FEATURES:
// Disambiguate outputFormat (the AUHAL's stream format)
// More nuanced input detection on the Mac
// Route switching should work, check with iPhone
// Device switching should work, check with laptop. Read that damn book.
// Wrap logging with debug macros.
// Think about what should be public, what private.
// Ability to select non-default devices.


#import "Novocaine.h"
#define kInputBus 1
#define kOutputBus 0
#define kDefaultDevice 999999

#import "TargetConditionals.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVAudioSession.h>

static Novocaine *audioManager = nil;

@interface Novocaine()
- (void)setupAudio;

- (NSString *)applicationDocumentsDirectory;

@end


@implementation Novocaine
@synthesize inputUnit;
@synthesize outputUnit;
@synthesize inputBuffer;
@synthesize inputRoute, inputAvailable;
@synthesize numInputChannels, numOutputChannels;
@synthesize inputBlock, outputBlock;
@synthesize samplingRate;
@synthesize isInterleaved;
@synthesize isSetUp;
@synthesize numBytesPerSample;
@synthesize inData;
@synthesize outData;
@synthesize playing;

@synthesize outputFormat;
@synthesize inputFormat;
// @synthesize playThroughEnabled;


#pragma mark - Singleton Methods
+ (Novocaine *) audioManager
{
	@synchronized(self)
	{
		if (audioManager == nil) {
			audioManager = [[Novocaine alloc] init];
		}
	}
    return audioManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (audioManager == nil) {
            audioManager = [super allocWithZone:zone];
            return audioManager;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

//- (id)copyWithZone:(NSZone *)zone
//{
//    return self;
//}

//- (id)retain {
//    return self;
//}
//
//- (NSUInteger)retainCount {
//    return (NSUInteger)UINT_MAX;  // denotes an object that cannot be released
//}
//
//- (oneway void)release {
//    //do nothing
//}

- (id)init
{
	if (self = [super init])
	{
		
		// Initialize some stuff k?
        outputBlock		= nil;
		inputBlock	= nil;
        
        // Initialize a float buffer to hold audio
		self.inData  = (float *)calloc(8192, sizeof(float)); // probably more than we'll need
        self.outData = (float *)calloc(8192, sizeof(float));
        
        self.inputBlock = nil;
        self.outputBlock = nil;
        
        self.playing = NO;
        // self.playThroughEnabled = NO;
		
		// Fire up the audio session ( with steady error checking ... )
        [self ifAudioInputIsAvailableThenSetupAudioSession];
		
		return self;
		
	}
	
	return nil;
}


#pragma mark - Block Handling
- (void)setInputBlock:(InputBlock)newInputBlock
{
    InputBlock tmpBlock = inputBlock;
    inputBlock = Block_copy(newInputBlock);
    Block_release(tmpBlock);
}

- (void)setOutputBlock:(OutputBlock)newOutputBlock
{
    OutputBlock tmpBlock = outputBlock;
    outputBlock = Block_copy(newOutputBlock);
    Block_release(tmpBlock);
}



#pragma mark - Audio Methods


- (void)ifAudioInputIsAvailableThenSetupAudioSession {
    
	// Initialize and configure the audio session, and add an interuption listener
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionDidChangeListener:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
    // Check the session properties (available input routes, number of channels, etc)
    [self checkAudioSource];

    
    // If we do have input, then let's rock 'n roll.
	if (self.inputAvailable) {
		[self setupAudio];
		[self play];
	}
    
    // If we don't have input, then ask the user to provide some
	else
    {
		UIAlertView *noInputAlert =
		[[UIAlertView alloc] initWithTitle:@"No Audio Input"
								   message:@"Couldn't find any audio input. Plug in your Apple headphones or another microphone."
								  delegate:self
						 cancelButtonTitle:@"OK"
						 otherButtonTitles:nil];
		
		[noInputAlert show];
		[noInputAlert release];
        
	}
}

- (void) teardownAudio {
  if (!isSetUp)
    return;
  
  [self pause];
    
  NSError *error = nil;
  
  NSLog(@"Tearing down audio session");
    
  // Set the audio session to not active
    if(![[AVAudioSession sharedInstance] setActive:NO error:&error]){
        NSLog(@"%@ Couldn't activate audio session %@",
              NSStringFromSelector(_cmd), [error localizedDescription]);
        @throw error;
    }
  
    
  //CheckError( AudioSessionSetActive(NO), "Couldn't de-activate the audio session");
  
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
  // Remove a property listener, to listen to changes to the session
//  CheckError( AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, sessionPropertyListener, self), "Couldn't remove audio session property listener");

  // Uninitialize and dispose the audio input unit
  CheckError( AudioUnitUninitialize(self.inputUnit), "Couldn't uninitialize audio input unit");
  CheckError( AudioComponentInstanceDispose(self.inputUnit), "Couldn't dispose of audio input unit");
  self.inputUnit = nil;
  
  
  isSetUp = NO;
}


- (void)setupAudio
{
  
  if (isSetUp)
    return;
  NSError *error = nil;
  NSLog(@"Setting up audio session");
  
    // --- Audio Session Setup ---
    // ---------------------------
    // Initialize the audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // configure session to be input from microphone only, other options include: AVAudioSessionCategoryPlayAndRecord, AVAudioSessionCategoryAudioProcessing, AVAudioSessionCategoryRecord but Record is ideal for our application because we are doing "online" processing
    if(![session setCategory:AVAudioSessionCategoryPlayAndRecord
                       error:&error])
    {
        NSLog(@"%@ Error setting category: %@",
              NSStringFromSelector(_cmd), [error localizedDescription]);
        @throw error;
    }

    
    // Set the audio session active
    if(![session setActive:YES error:&error])
    {
        NSLog(@"%@ Couldn't activate audio session %@",
              NSStringFromSelector(_cmd), [error localizedDescription]);
        @throw error;
    }
    
    
    // Code inserted by Eric Larson for msetting audio route
    // Get the set of available inputs. If there are no audio accessories attached, there will be
    // only one available input -- the built in microphone.
//    NSArray* inputs = [session availableInputs];
//    
//    // Locate the Port corresponding to the built-in microphone.
//    AVAudioSessionPortDescription* builtInMicPort = nil;
//    for (AVAudioSessionPortDescription* port in inputs)
//    {
//        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic])
//        {
//            builtInMicPort = port;
//            break;
//        }
//    }
//    
//    // Print out a description of the data sources for the built-in microphone
//    NSLog(@"There are %u data sources for port :\"%@\"", (unsigned)[builtInMicPort.dataSources count], builtInMicPort);
//    NSLog(@"%@", builtInMicPort.dataSources);
//    
//    // loop over the built-in mic's data sources and attempt to locate the front microphone
//    AVAudioSessionDataSourceDescription* frontDataSource = nil;
//    for (AVAudioSessionDataSourceDescription* source in builtInMicPort.dataSources)
//    {
//        // other options:
//        //      AVAudioSessionOrientation( Top | {Front} | Back | Bottom )
//        if ([source.orientation isEqual:AVAudioSessionOrientationBottom])
//        {
//            frontDataSource = source;
//            break;
//        }
//    } // end data source iteration
//    
//    if (frontDataSource)
//    {
//        NSLog(@"Currently selected source is \"%@\" for port \"%@\"", builtInMicPort.selectedDataSource.dataSourceName, builtInMicPort.portName);
//        NSLog(@"Attempting to select source \"%@\" on port \"%@\"", frontDataSource, builtInMicPort.portName);
//        
//        // Set a preference for the front data source.
//        error = nil;
//        if (![builtInMicPort setPreferredDataSource:frontDataSource error:&error])
//        {
//            // an error occurred.
//            NSLog(@"setPreferredDataSource failed");
//        }
//    }
//    else{
//        NSLog(@"Front Data Source is nil, cannot change source.");
//    }
//    
//    // Make sure the built-in mic is selected for input. This will be a no-op if the built-in mic is
//    // already the current input Port.
//    error = nil;
//    if(![session setPreferredInput:builtInMicPort error:&error]){
//        NSLog(@"%@ Couldn't set mic as preferred port %@",
//              NSStringFromSelector(_cmd), [error localizedDescription]);
//        @throw error;
//    }
    
    // Add a property listener, to listen to changes to the Route of Audio Input
//    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
//    [nc addObserver:self selector:@selector(audioRouteChangedListener:) name:AVAudioSessionRouteChangeNotification object:nil];
    
    // Set the buffer size, this will affect the number of samples that get rendered every time the audio callback is fired
    // A small number will get you lower latency audio, but will make your processor work harder
#if !TARGET_IPHONE_SIMULATOR
    Float32 preferredBufferSize = 0.0232;
    [session setPreferredIOBufferDuration:preferredBufferSize error:&error];
    //CheckError( AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "Couldn't set the preferred buffer duration");
#endif

    
    [self checkSessionProperties];
  
    
    
    // ----- Audio Unit Setup -----
    // ----------------------------
    
    
    // Describe the output unit.
    AudioComponentDescription inputDescription = {0};
    inputDescription.componentType = kAudioUnitType_Output;
    inputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    inputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    

    
    
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputDescription);
    CheckError( AudioComponentInstanceNew(inputComponent, &inputUnit), "Couldn't create the output audio unit");
    
    
    // Enable input
    UInt32 one = 1;
    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioOutputUnitProperty_EnableIO, 
                                     kAudioUnitScope_Input, 
                                     kInputBus, 
                                     &one, 
                                     sizeof(one)), "Couldn't enable IO on the input scope of output unit");
    
    // TODO: first query the hardware for desired stream descriptions
    // Check the input stream format
    
    UInt32 size;
	size = sizeof( AudioStreamBasicDescription );
	CheckError( AudioUnitGetProperty( inputUnit, 
                                     kAudioUnitProperty_StreamFormat, 
                                     kAudioUnitScope_Input, 
                                     1, 
                                     &inputFormat, 
                                     &size ), 
               "Couldn't get the hardware input stream format");
	
	// Check the output stream format
	size = sizeof( AudioStreamBasicDescription );
	CheckError( AudioUnitGetProperty( inputUnit, 
                                     kAudioUnitProperty_StreamFormat, 
                                     kAudioUnitScope_Output, 
                                     1, 
                                     &outputFormat, 
                                     &size ), 
               "Couldn't get the hardware output stream format");
    
    inputFormat.mSampleRate = 44100.0;
    outputFormat.mSampleRate = 44100.0;
    self.samplingRate = inputFormat.mSampleRate;
    self.numBytesPerSample = inputFormat.mBitsPerChannel / 8;
    
    size = sizeof(AudioStreamBasicDescription);
	CheckError(AudioUnitSetProperty(inputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									kInputBus,
									&outputFormat,
									size),
			   "Couldn't set the ASBD on the audio unit (after setting its sampling rate)");
    
    

    
    
    UInt32 numFramesPerBuffer;
    size = sizeof(UInt32);
    CheckError(AudioUnitGetProperty(inputUnit, 
                                    kAudioUnitProperty_MaximumFramesPerSlice,
                                    kAudioUnitScope_Global, 
                                    kOutputBus, 
                                    &numFramesPerBuffer, 
                                    &size), 
               "Couldn't get the number of frames per callback");
    
    UInt32 bufferSizeBytes = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket * numFramesPerBuffer;
    
    
    
    
	if (outputFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        // The audio is non-interleaved
        printf("Not interleaved!\n");
        self.isInterleaved = NO;
        
        // allocate an AudioBufferList plus enough space for array of AudioBuffers
		UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * outputFormat.mChannelsPerFrame);
		
		//malloc buffer lists
		self.inputBuffer = (AudioBufferList *)malloc(propsize);
		self.inputBuffer->mNumberBuffers = outputFormat.mChannelsPerFrame;
		
		//pre-malloc buffers for AudioBufferLists
		for(UInt32 i =0; i< self.inputBuffer->mNumberBuffers ; i++) {
			self.inputBuffer->mBuffers[i].mNumberChannels = 1;
			self.inputBuffer->mBuffers[i].mDataByteSize = bufferSizeBytes;
			self.inputBuffer->mBuffers[i].mData = malloc(bufferSizeBytes);
            memset(self.inputBuffer->mBuffers[i].mData, 0, bufferSizeBytes);
		}
        
	} else {
		printf ("Format is interleaved\n");
        self.isInterleaved = YES;
        
		// allocate an AudioBufferList plus enough space for array of AudioBuffers
		UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * 1);
		
		//malloc buffer lists
		self.inputBuffer = (AudioBufferList *)malloc(propsize);
		self.inputBuffer->mNumberBuffers = 1;
		
		//pre-malloc buffers for AudioBufferLists
		self.inputBuffer->mBuffers[0].mNumberChannels = outputFormat.mChannelsPerFrame;
		self.inputBuffer->mBuffers[0].mDataByteSize = bufferSizeBytes;
		self.inputBuffer->mBuffers[0].mData = malloc(bufferSizeBytes);
        memset(self.inputBuffer->mBuffers[0].mData, 0, bufferSizeBytes);
        
	}
    
    
    // Slap a render callback on the unit
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = inputCallback;
    callbackStruct.inputProcRefCon = self;
    
    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioOutputUnitProperty_SetInputCallback, 
                                     kAudioUnitScope_Global,
                                     0, 
                                     &callbackStruct, 
                                     sizeof(callbackStruct)), "Couldn't set the callback on the input unit");
    
    
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = self;

    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioUnitProperty_SetRenderCallback, 
                                     kAudioUnitScope_Input,
                                     0,
                                     &callbackStruct, 
                                     sizeof(callbackStruct)), 
               "Couldn't set the render callback on the input unit");    
    
    
    
    
	CheckError(AudioUnitInitialize(inputUnit), "Couldn't initialize the output unit");

  
	isSetUp = YES;
}



- (void)pause {
	
	if (playing) {
        CheckError( AudioOutputUnitStop(inputUnit), "Couldn't stop the output unit");
		playing = NO;
	}
    
}

- (void)play {
    
    AVAudioSession *session =  [AVAudioSession sharedInstance];

    self.inputAvailable = session.isInputAvailable;
    
	if ( self.inputAvailable ) {
		// Set the audio session category for simultaneous play and record
		if (!playing) {
			CheckError( AudioOutputUnitStart(inputUnit), "Couldn't start the output unit");
            self.playing = YES;
            
		}
	}
    
}


#pragma mark - Render Methods
OSStatus inputCallback   (void						*inRefCon,
                          AudioUnitRenderActionFlags	* ioActionFlags,
                          const AudioTimeStamp 		* inTimeStamp,
                          UInt32						inOutputBusNumber,
                          UInt32						inNumberFrames,
                          AudioBufferList			* ioData)
{
    
    
	Novocaine *sm = (Novocaine *)inRefCon;
    
    if (!sm.playing)
        return noErr;
    if (sm.inputBlock == nil)
        return noErr;    
    
    
    // Check the current number of channels		
    // Let's actually grab the audio
#if TARGET_IPHONE_SIMULATOR
    // this is a workaround for an issue with core audio on the simulator, //
    //  likely due to 44100 vs 48000 difference in OSX //
    if( inNumberFrames == 471 )
        inNumberFrames = 470;
#endif
    CheckError( AudioUnitRender(sm.inputUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, sm.inputBuffer), "Couldn't render the output unit");
    
    
    // Convert the audio in something manageable
    // For Float32s ... 
    if ( sm.numBytesPerSample == 4 ) // then we've already got floats
    {
        
        float zero = 0.0f;
        if ( ! sm.isInterleaved ) { // if the data is in separate buffers, make it interleaved
            for (int i=0; i < sm.numInputChannels; ++i) {
                vDSP_vsadd((float *)sm.inputBuffer->mBuffers[i].mData, 1, &zero, sm.inData+i, 
                           sm.numInputChannels, inNumberFrames);
            }
        } 
        else { // if the data is already interleaved, copy it all in one happy block.
            // TODO: check mDataByteSize is proper 
            memcpy(sm.inData, (float *)sm.inputBuffer->mBuffers[0].mData, sm.inputBuffer->mBuffers[0].mDataByteSize);
        }
    }
    
    // For SInt16s ...
    else if ( sm.numBytesPerSample == 2 ) // then we're dealing with SInt16's
    {
        if ( ! sm.isInterleaved ) {
            for (int i=0; i < sm.numInputChannels; ++i) {
                vDSP_vflt16((SInt16 *)sm.inputBuffer->mBuffers[i].mData, 1, sm.inData+i, sm.numInputChannels, inNumberFrames);
            }            
        }
        else {
            vDSP_vflt16((SInt16 *)sm.inputBuffer->mBuffers[0].mData, 1, sm.inData, 1, inNumberFrames*sm.numInputChannels);
        }
        
        float scale = 1.0 / (float)INT16_MAX;
        vDSP_vsmul(sm.inData, 1, &scale, sm.inData, 1, inNumberFrames*sm.numInputChannels);
    }
    
    // Now do the processing! 
    sm.inputBlock(sm.inData, inNumberFrames, sm.numInputChannels);
    
    return noErr;
	
	
}

OSStatus renderCallback (void						*inRefCon,
                         AudioUnitRenderActionFlags	* ioActionFlags,
                         const AudioTimeStamp 		* inTimeStamp,
                         UInt32						inOutputBusNumber,
                         UInt32						inNumberFrames,
                         AudioBufferList				* ioData)
{
    
    
	Novocaine *sm = (Novocaine *)inRefCon;    
    float zero = 0.0;
    
    
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {        
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (!sm.playing)
        return noErr;
    if (!sm.outputBlock)
        return noErr;


    // Collect data to render from the callbacks
    sm.outputBlock(sm.outData, inNumberFrames, sm.numOutputChannels);
    
    
    // Put the rendered data into the output buffer
    // TODO: convert SInt16 ranges to float ranges.
    if ( sm.numBytesPerSample == 4 ) // then we've already got floats
    {
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {  
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vsadd(sm.outData+iChannel, sm.numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, inNumberFrames);
            }
        }
    }
    else if ( sm.numBytesPerSample == 2 ) // then we need to convert SInt16 -> Float (and also scale)
    {
        float scale = (float)INT16_MAX;
        vDSP_vsmul(sm.outData, 1, &scale, sm.outData, 1, inNumberFrames*sm.numOutputChannels);
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {  
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vfix16(sm.outData+iChannel, sm.numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, inNumberFrames);
            }
        }
        
    }

    return noErr;
    
}	

#pragma mark - Audio Session Listeners
void sessionPropertyListener(void *                  inClientData,
							 AudioSessionPropertyID  inID,
							 UInt32                  inDataSize,
							 const void *            inData){
	
    
	if (inID == kAudioSessionProperty_AudioRouteChange)
    {
        Novocaine *sm = (Novocaine *)inClientData;
        [sm checkSessionProperties];
    }
    
}

- (void)audioSessionDidChangeListener:(NSNotification *)notification
{
    NSLog(@"Called interuption");
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo]
                                                        objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType)
    {
        NSLog(@"Begin interuption");
        self.inputAvailable = NO;
    }
    else if (AVAudioSessionInterruptionTypeEnded == interruptionType)
    {
        NSLog(@"End interuption");
		self.inputAvailable = YES;
		[self play];
        
    }
    
}



//- (void) audioRouteChangedListener:(NSNotification*)notification
//{
//
//    NSLog(@"audioRouteChanged");
//    [self checkSessionProperties];
//    
//    //    UInt32 routeSize = sizeof (CFStringRef);
//    //    CFStringRef route;
//    //
//    //    OSStatus error = AudioSessionGetProperty (kAudioSessionProperty_AudioRoute, &routeSize, &route);
//    
//    /* Known values of route:
//     * "Headset"
//     * "Headphone"
//     * "Speaker"
//     * "SpeakerAndMicrophone"
//     * "HeadphonesAndMicrophone"
//     * "HeadsetInOut"
//     * "ReceiverAndMicrophone"
//     * "Lineout"
//     */
//    
//    
//}

- (void)checkAudioSource {
    // Check what the incoming audio route is.
    //UInt32 propertySize = sizeof(CFStringRef);
    //CFStringRef route;
    
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    //CheckError( AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route), "Couldn't check the audio route");
    //self.inputRoute = (NSString *)route;
    //CFRelease(route);
    //NSLog(@"AudioRoute: %@", self.inputRoute);
    
    // Check if there's input available.
    // TODO: check if checking for available input is redundant.
    //          Possibly there's a different property ID change?
    self.inputAvailable = session.isInputAvailable;
    NSLog(@"Input available? %d", self.inputAvailable);
    
}


// To be run ONCE per session property change and once on initialization.
- (void)checkSessionProperties
{	
    NSLog(@"Checking session properties");
  
    // Check if there is input, and from where
    [self checkAudioSource];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // Check the number of input channels.
    // Find the number of channels
    self.numInputChannels = session.inputNumberOfChannels;
    //    self.numInputChannels = 1;
    NSLog(@"We've got %u input channels", (unsigned int)self.numInputChannels);
    
    
    // Check the number of input channels.
    // Find the number of channels
    self.numOutputChannels = session.outputNumberOfChannels;
    //    self.numOutputChannels = 1;
    NSLog(@"We've got %u output channels", (unsigned int)self.numOutputChannels);
    
    
    // Get the hardware sampling rate. This is settable, but here we're only reading.

    self.samplingRate = session.sampleRate;
    NSLog(@"Current sampling rate: %f", self.samplingRate);
	
}

void sessionInterruptionListener(void *inClientData, UInt32 inInterruption) {
    
	Novocaine *sm = (Novocaine *)inClientData;
    
	if (inInterruption == kAudioSessionBeginInterruption) {
		NSLog(@"Begin interuption");
		sm.inputAvailable = NO;
	}
	else if (inInterruption == kAudioSessionEndInterruption) {
		NSLog(@"End interuption");	
		sm.inputAvailable = YES;
		[sm play];
	}
	
}


#pragma mark - Convenience Methods
- (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}

@end








