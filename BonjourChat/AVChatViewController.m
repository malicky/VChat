//
//  AVChatViewController.m
//  BonjourChat
//
//  Created by Malick Youla on 2014-08-20.
//  Copyright (c) 2014 Oliver Drobnik. All rights reserved.
//

#import "AVChatViewController.h"
#import "DTBonjourDataConnection.h"
#import "DTBonjourServer.h"
#import "BonjourChatServer.h"
#import "BonjourChatClient.h"
#import "AVCamPreviewView.h"
#import "AppDelegate.h"
#import "ChatRoomTableViewController.h"
#import "VDLViewController.h"

@interface AVChatViewController () <DTBonjourDataConnectionDelegate, DTBonjourServerDelegate>

@end

@implementation AVChatViewController
{
    BonjourChatServer *_server;
    BonjourChatClient *_client;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if ( self.ipAdressOfOtherRoom ) {
        NSString *ipAdressOfOtherRoom = [[NSString alloc] initWithData:self.ipAdressOfOtherRoom encoding:NSUTF8StringEncoding];
        NSLog(@"Opponent iP Adress = %@", ipAdressOfOtherRoom);
        
       // [self.view removeConstraints:self.previewView.constraints];
      //  self.previewView.frame = CGRectMake(0, 0, 150, 150);
    }
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    
	if ([self.chatRoom isKindOfClass:[BonjourChatServer class]])
	{
		_server = self.chatRoom;
		_server.delegate = self;
		self.navigationItem.title = _server.roomName;
	}
	else if ([self.chatRoom isKindOfClass:[NSNetService class]])
	{
		NSNetService *service = self.chatRoom;
		
		_client = [[BonjourChatClient alloc] initWithService:service];
		_client.delegate = self;
		[_client open];
        
		// reduce the size
        //self.previewView.frame = CGRectMake(0, 0, 100, 100);
        
		self.navigationItem.title = _client.roomName;
	}
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}


#pragma mark - DTBonjourServer Delegate (Server)

- (void)bonjourServer:(DTBonjourServer *)server didAcceptConnection:(DTBonjourDataConnection *)connection ipAdress:(NSString*)ipString port:(int)port
{
    self.ipAdressOfOtherRoom = [ipString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *ipAdressOfOtherRoom = [[NSString alloc] initWithData:self.ipAdressOfOtherRoom encoding:NSUTF8StringEncoding];
    NSLog(@"Opponent iP Adress = %@", ipAdressOfOtherRoom);
    
    // Delay execution of my block for 10 seconds.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        //_destination.chatRoom = _foundServices[indexPath.row];
        //_destination.ipAdressOfOtherRoom = _foundServicesIpAdresses[indexPath.row];
        self.otherVDLChatRoom = [[VDLViewController alloc]initWithData:self.ipAdressOfOtherRoom];
        [self addChildViewController:self.otherVDLChatRoom];
        [self.view addSubview:self.otherVDLChatRoom.view];
        [self.otherVDLChatRoom didMoveToParentViewController:self];
        self.previewView.draggable = YES;
        [self.otherVDLChatRoom rotate];
//set to zero the origin because of some strange values may happend
        CGRect r = self.otherVDLChatRoom.view.frame;
        r.origin.x = r.origin.y = 0.;
        self.otherVDLChatRoom.view.frame = r;
        
        CGRect previewView = self.previewView.frame;
        CGRect otherVDLChatRoomview = self.otherVDLChatRoom.view.frame;
        NSLog(@"frame previewView %@", NSStringFromCGRect(previewView));
        NSLog(@"frame otherVDLChatRoomview %@", NSStringFromCGRect(otherVDLChatRoomview));

    });
   

//
//    NSArray *vc = self.navigationController.viewControllers ; // YES!! it works
//    
//    if ([vc[0] isKindOfClass:[ChatRoomTableViewController class]]) {
//    //  [self.navigationController popToViewController:vc[0] animated:YES];
//        [vc[0] connectToRoom:ipAdressOfOtherRoom];
////        [(ChatRoomTableViewController *)vc[0] performSegueWithIdentifier:@"ChatRoom" sender:self];
//    }
//
//   

}

- (void)bonjourServer:(DTBonjourServer *)server didReceiveObject:(id)object onConnection:(DTBonjourDataConnection *)connection
{
	//[_messages insertObject:object atIndex:0];
	//[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1]] withRowAnimation:UITableViewRowAnimationTop];
}

#pragma mark - DTBonjourConnection Delegate (Client)

- (void)connection:(DTBonjourDataConnection *)connection didReceiveObject:(id)object
{
	//[_messages insertObject:object atIndex:0];
	//[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1]] withRowAnimation:UITableViewRowAnimationTop];
}

- (void)connectionDidClose:(DTBonjourDataConnection *)connection
{
	if (connection == _client)
	{
        NSString *message = [NSString stringWithFormat:@"The Server %@ has closed the room.", __AppDelegate.deviceType];
        
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Room Closed 1" message:message delegate:self cancelButtonTitle:@"Exit" otherButtonTitles:nil];
		[alert show];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	[self.navigationController popViewControllerAnimated:YES];
}

@end
