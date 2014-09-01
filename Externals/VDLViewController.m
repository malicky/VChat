/* Copyright (c) 2013, Felix Paul Kühne and VideoLAN
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, 
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE. */

#import "VDLViewController.h"
#import <CoreGraphics/CoreGraphics.h>
#import "AppDelegate.h"
#import "AVCamViewController.h"
#import "AVCamPreviewView.h"
//#define debug

@interface VDLViewController ()
{
    VLCMediaPlayer *_mediaplayer;
    NSString *_ipAdressOpponent;
}

@end

@implementation VDLViewController

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (instancetype)initWithData:(NSData*)data
{
    self = [super init];
    if (self) {
        NSString *ipAdressOfOtherRoom = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Opponent iP Adress = %@", ipAdressOfOtherRoom);
        _ipAdressOpponent = ipAdressOfOtherRoom;

    }
    return self;
}



- (void)viewDidLoad
{
    [super viewDidLoad];

    /* setup the media player instance, give it a delegate and something to draw into */
    _mediaplayer = [[VLCMediaPlayer alloc] init];
    _mediaplayer.delegate = self;
    
    //[self rotate];
    
    _mediaplayer.drawable = self.movieView = self.view;

    /* create a media object and give it to the player */
    //_mediaplayer.media = [VLCMedia mediaWithURL:[NSURL URLWithString:@"http://streams.videolan.org/streams/mp4/Mr_MrsSmith-h264_aac.mp4"]];
    
    NSString* urlString = urlString = [NSString stringWithFormat:@"rtsp://%@/", _ipAdressOpponent];

      _mediaplayer.media = [VLCMedia mediaWithURL:[NSURL URLWithString:urlString]];
    [_mediaplayer play];
    
}

- (void)rotate:(BOOL)must {
    if (must)
    {
        
        CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI);
        self.movieView.transform = transform;
    }
}

- (IBAction)playandPause:(id)sender
{
    if (_mediaplayer.isPlaying)
        [_mediaplayer pause];

    [_mediaplayer play];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    short __unused aidx = _mediaplayer.currentAudioTrackIndex;
    VLCMediaPlayerState currentState = _mediaplayer.state;
#ifdef debug
    NSLog(@" %@ %@",  VLCMediaPlayerStateToString(currentState),  __AppDelegate.deviceType );
#endif
    /* distruct view controller on error */
    if (currentState == VLCMediaPlayerStateError) {
        [self performSelector:@selector(closePlayback:) withObject:nil afterDelay:2.];
    }
    
    /* or if playback ended */
    if (currentState == VLCMediaPlayerStateEnded || currentState == VLCMediaPlayerStateStopped) {
        [self performSelector:@selector(closePlayback:) withObject:nil afterDelay:2.];
    }
}

- (IBAction)closePlayback:(id)sender
{
    //[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    AVCamViewController *avc = (AVCamViewController *)parent;
    UIView *preview = (UIView *)avc.previewView;
    preview.frame = CGRectMake (0, 0, 100. ,100);
    [avc.view bringSubviewToFront:preview];
    avc.previewView.draggable = YES;
    BOOL mustRotate = avc.mustRotate;
    [avc.otherVDLChatRoom rotate:mustRotate];
#if 0
    //set to zero the origin because of some strange values may happend
    CGRect r = avc.otherVDLChatRoom.view.frame;
    r.origin.x = r.origin.y = 0.;
    avc.otherVDLChatRoom.view.frame = r;
    
    NSLog(@"frame previewView %@", NSStringFromCGRect(avc.previewView.frame));
    NSLog(@"frame otherVDLChatRoomview %@", NSStringFromCGRect(avc.otherVDLChatRoom.view.frame));
#endif
    
}



@end
