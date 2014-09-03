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

@interface CameraServer  () 
{
    AVEncoder* _encoder;
    RTSPServer* _rtsp;
}
@end


@implementation CameraServer

- (void)encode:(CMSampleBufferRef)sampleBuffer
{
     [_encoder encodeFrame:sampleBuffer];
}

- (void)initWithCamViewController:(AVCamViewController*)AVC {
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

- (void) shutdown
{
    NSLog(@"shutting down RTSP Camera server");
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


@end
