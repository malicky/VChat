//
//  CameraServer.m
//  Encoder Demo
//
//  Created by Geraint Davies on 19/02/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import "CameraServer.h"
#import "AVEncoder.h"
#import "RTSPServer.h"
#import "AVCamPreviewView.h"
#import <AVFoundation/AVAudioSettings.h>
#import <AVFoundation/AVCaptureOutput.h>

static CameraServer* theServer;

@interface CameraServer  () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    AVCaptureSession* _session;
    AVCaptureVideoPreviewLayer* _preview;
    AVCaptureVideoDataOutput* _videoOutput;
    AVCaptureAudioDataOutput* _audioOutput;
    dispatch_queue_t _captureQueue;
    
    AVEncoder* _encoder;
    
    RTSPServer* _rtsp;
}
@end


@implementation CameraServer

- (void)initWithCamViewController:(AVCamViewController*)AVC {

    _session = AVC.session;
    _captureQueue = AVC.sessionQueue;
    
    
    // create an output for YUV output with self as delegate
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput.alwaysDiscardsLateVideoFrames = NO;
    NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                        nil];
    _videoOutput.videoSettings = setcapSettings;
    
    if ([_session canAddOutput:_videoOutput]) {
        [_session addOutput:_videoOutput];//##
    }
    [_videoOutput setSampleBufferDelegate:self queue:_captureQueue];


    // Setup the audio output
//    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
//    [_session addOutput:_audioOutput];
//    [_audioOutput setSampleBufferDelegate:self queue:_captureQueue];
//    
    
    _preview = (AVCaptureVideoPreviewLayer *)[[AVC previewView] layer];
    _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    
    // create an encoder
    _encoder = [AVEncoder encoderForHeight:480 andWidth:720];
    [_encoder encodeWithBlock:^int(NSArray* data, double pts) {
        if (_rtsp != nil)
        {
            _rtsp.bitrate = _encoder.bitspersecond;
            [_rtsp onVideoData:data time:pts];
        }
        return 0;

    } onParams:^int(NSData *data) {
        _rtsp = [RTSPServer setupListener:data];
        return 0;

    }];
    

   }

+ (instancetype)sharedInstance {
    static id sharedInstance;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });
    
    return sharedInstance;
}



+ (CameraServer*) server
{
    return theServer;
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // pass frame to encoder
    [_encoder encodeFrame:sampleBuffer];
}

- (void)restartSession {
     NSLog(@"restart Session");
    if (_session)
    {
        [_session startRunning];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"sessionRunningAndDeviceRestarted" object:self];
    }
}
- (void) shutdown
{
    NSLog(@"shutting down RTSP Camera server");
    if (_session)
    {
        [_session stopRunning];
        _session = nil;
    }
    if (_rtsp)
    {
        [_rtsp shutdownServer];
    }
    if (_encoder)
    {
        [ _encoder shutdown];
    }
}

- (NSString*) getURL
{
    NSString* ipaddr = [RTSPServer getIPAddress];
    NSString* url = [NSString stringWithFormat:@"rtsp://%@/", ipaddr];
    return url;
}

- (AVCaptureVideoPreviewLayer*) getPreviewLayer
{
    return _preview;
}

@end
