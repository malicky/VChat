//
//  AVChatViewController.h
//  BonjourChat
//
//  Created by Malick Youla on 2014-08-20.
//  Copyright (c) 2014 Oliver Drobnik. All rights reserved.
//

#import "AVCamViewController.h"

@interface AVChatViewController : AVCamViewController
@property (nonatomic, strong) id chatRoom;
@property (nonatomic, strong) NSData * ipAdressOfOtherRoom;

- (void) restartCameraServer;
@end
