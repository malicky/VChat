//
//  VideoEncoder.m
//  Encoder Demo
//
//  Created by Geraint Davies on 14/01/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import "VideoEncoder.h"

#import <AVFoundation/AVAudioSettings.h>


@implementation VideoEncoder

@synthesize path = _path;

+ (VideoEncoder*) encoderForPath:(NSString*) path Height:(int) height andWidth:(int) width
{
    VideoEncoder* enc = [VideoEncoder alloc];
    [enc initPath:path Height:height andWidth:width];
    return enc;
}


- (void) initPath:(NSString*)path Height:(int) height andWidth:(int) width
{
    self.path = path;
    
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
    NSURL* url = [NSURL fileURLWithPath:self.path];
    NSError *error = nil;
    _writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:&error];
    
    if (error)
    {
        NSLog(@"%@", error);
    }

    
    NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              AVVideoCodecH264, AVVideoCodecKey,
                              [NSNumber numberWithInt: width], AVVideoWidthKey,
                              [NSNumber numberWithInt:height], AVVideoHeightKey,
                              [NSDictionary dictionaryWithObjectsAndKeys:
                                    @YES, AVVideoAllowFrameReorderingKey, nil],
                                    AVVideoCompressionPropertiesKey,
                              nil];
    _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    
 
    _writerInput.expectsMediaDataInRealTime = YES;
    [_writer addInput:_writerInput];
    
    // Add the audio input
//    AudioChannelLayout acl;
//    bzero( &acl, sizeof(acl));
//    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
//
//    NSDictionary* audioOutputSettings = nil;
//    audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys:
//                           [ NSNumber numberWithInt: kAudioFormatAppleLossless ], AVFormatIDKey,
//                           [ NSNumber numberWithInt: 16 ], AVEncoderBitDepthHintKey,
//                           [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
//                           [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
//                           [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
//                           nil ];
//    _audioWriterInput = [AVAssetWriterInput
//                          assetWriterInputWithMediaType: AVMediaTypeAudio
//                          outputSettings: audioOutputSettings ];
//    
//    _audioWriterInput.expectsMediaDataInRealTime = YES;
//
//    [_writer addInput:_audioWriterInput];

}

- (void) finishWithCompletionHandler:(void (^)(void))handler
{
    @try
    {
        [_writer finishWritingWithCompletionHandler: handler];
    }
    @catch (NSException *exception)
    {
        NSLog (@"%@", exception);
    }
}

- (BOOL) encodeFrame:(CMSampleBufferRef) sampleBuffer
{
    if (CMSampleBufferDataIsReady(sampleBuffer))
    {
        if (_writer.status == AVAssetWriterStatusUnknown)
        {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [_writer startWriting];
            [_writer startSessionAtSourceTime:startTime];
        }
        if (_writer.status == AVAssetWriterStatusFailed)
        {
            NSLog(@"writer error %@", _writer.error.localizedDescription);
            return NO;
        }
        if (_writerInput.readyForMoreMediaData == YES)
        {
            [_writerInput appendSampleBuffer:sampleBuffer];
            return YES;
        }
    }
    return NO;
}

@end
