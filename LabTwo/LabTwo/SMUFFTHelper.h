//
//  SMUFFTHelper.h
//  NovocaineExample
//
//*  Real FFT wrapper for Apple's Accelerate Framework
//*
//*  Created by Parag K. Mital - http://pkmital.com
//*  Contact: parag@pkmital.com
//*
//*  Copyright 2011 Parag K. Mital. All rights reserved.
//  Modified by Eric Larson 2013.
//  Copyright (c) 2013 Eric Larson. All rights reserved.
//

#ifndef NovocaineExample_SMUFFTHelper_h
#define NovocaineExample_SMUFFTHelper_h

#include <Accelerate/Accelerate.h>

enum WindowType {
    WindowTypeHann,
    WindowTypeHamming,
    WindowTypeRect,
    WindowTypeBlackman,
    };

class SMUFFTHelper
{
public:
    
    SMUFFTHelper(int size = 4096, int window_size = 4096, WindowType winType = WindowTypeHann)
    {
        fftSize = size;                 // sample size
        fftSizeOver2 = fftSize/2;
        log2n = log2f(fftSize);         // bins
        log2nOver2 = log2n/2;
        
        in_real = (float *) malloc(fftSize * sizeof(float));
        out_real = (float *) malloc(fftSize * sizeof(float));
        split_data.realp = (float *) malloc(fftSizeOver2 * sizeof(float));
        split_data.imagp = (float *) malloc(fftSizeOver2 * sizeof(float));
        
        if(winType != WindowTypeRect){
            windowSize = window_size;
            window = (float *) malloc(sizeof(float) * windowSize);
            memset(window, 0, sizeof(float) * windowSize);
            switch (winType) {
                case WindowTypeHann:
                    vDSP_hann_window(window, window_size, vDSP_HANN_DENORM);
                    break;
                case WindowTypeHamming:
                    vDSP_hamm_window(window, window_size, vDSP_HANN_DENORM);                    
                    break;
                case WindowTypeBlackman:
                    vDSP_blkman_window(window, window_size, vDSP_HANN_DENORM);
                    break;
                default:
                    vDSP_hann_window(window, window_size, vDSP_HANN_DENORM);
                    break;
            }
        
        }
        else{
            windowSize = 0;
            window = NULL;
        }
        
        scale = 1.0f/(float)(4.0f*fftSize);
        
        // allocate the fft object once
        fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
        if (fftSetup == NULL) {
            printf("\nFFT_Setup failed to allocate enough memory.\n");
        }
    }
    
    ~SMUFFTHelper()
    {
        free(in_real);
        free(out_real);
        free(split_data.realp);
        free(split_data.imagp);
        
        vDSP_destroy_fftsetup(fftSetup);
    }
    
    void forward(int start,
                 float *buffer,
                 float *magnitude,
                 float *phase)
    {
        if(magnitude==NULL || phase==NULL)
            return;
        
        //multiply by window
        if( window != NULL )
            vDSP_vmul(buffer, 1, window, 1, in_real, 1, fftSize);
        else
            memcpy(in_real,buffer,fftSize);
        
        //convert to split complex format with evens in real and odds in imag
        vDSP_ctoz((COMPLEX *) in_real, 2, &split_data, 1, fftSizeOver2);
        
        //calc fft
        vDSP_fft_zrip(fftSetup, &split_data, 1, log2n, FFT_FORWARD);
        
        split_data.imagp[0] = 0.0;
        
        for (i = 0; i < fftSizeOver2; i++)
        {
            //compute power
            float power = split_data.realp[i]*split_data.realp[i] +
            split_data.imagp[i]*split_data.imagp[i];
            
            //compute magnitude and phase
            magnitude[i] = sqrtf(power);
            phase[i] = atan2f(split_data.imagp[i], split_data.realp[i]);
        }
    }
    
    void inverse(int start,
                 float *buffer,
                 float *magnitude,
                 float *phase,
                 bool dowindow = true)
    {
        float *real_p = split_data.realp, *imag_p = split_data.imagp;
        for (i = 0; i < fftSizeOver2; i++) {
            *real_p++ = magnitude[i] * cosf(phase[i]);
            *imag_p++ = magnitude[i] * sinf(phase[i]);
        }
        
        vDSP_fft_zrip(fftSetup, &split_data, 1, log2n, FFT_INVERSE);
        vDSP_ztoc(&split_data, 1, (COMPLEX*) out_real, 2, fftSizeOver2);
        
        vDSP_vsmul(out_real, 1, &scale, out_real, 1, fftSize);
        
        // multiply by window w/ overlap-add
        if (dowindow) {
            float *p = buffer + start;
            for (i = 0; i < fftSize; i++) {
                *p++ += out_real[i] * window[i];
            }
        }
    }
    
    void allocateOutputs(float *allocated_magnitude_buffer,float *allocated_phase_buffer){
        allocated_magnitude_buffer =  (float *) malloc (sizeof(float) * fftSize);
        allocated_phase_buffer =  (float *) malloc (sizeof(float) * fftSizeOver2);
    }
    
private:
    
    size_t              fftSize,
    fftSizeOver2,
    log2n,
    log2nOver2,
    windowSize,
    i;
    
    float               *in_real,
    *out_real,
    *window;
    
    float               scale;
    
    FFTSetup            fftSetup;
    COMPLEX_SPLIT       split_data;
    
    
};

#endif
