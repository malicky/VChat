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
#import "CameraServer.h"

@interface AVChatViewController () <DTBonjourDataConnectionDelegate, DTBonjourServerDelegate,
NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@end

@implementation AVChatViewController
{
    BonjourChatServer *_server;
    BonjourChatClient *_client;
    
    NSMutableSet *_unidentifiedServices;
    NSMutableArray *_foundServices;
    NSMutableArray *_createdRooms;
    NSNetServiceBrowser *_serviceBrowser;
    NSMutableArray *_foundServicesIpAdresses;
    // AVChatViewController *_destination;
    BonjourChatServer *_bonjourChatServer;
    BOOL _mediaPlayerPlaying;
    IBOutlet UIBarButtonItem *_barButtonConnect;
}


- (void)awakeFromNib
{
	_foundServices = [[NSMutableArray alloc] init];
	_createdRooms = [[NSMutableArray alloc] init];
	_unidentifiedServices = [[NSMutableSet alloc] init];
    _foundServicesIpAdresses = [[NSMutableArray alloc] init];
    
	
	_serviceBrowser = [[NSNetServiceBrowser alloc] init];
	_serviceBrowser.delegate = self;
	[_serviceBrowser searchForServicesOfType:@"_BonjourVideoChat._tcp." inDomain:@""];
    
    _bonjourChatServer = [[BonjourChatServer alloc] initWithRoomName:@"Me"];
	[_createdRooms addObject:_bonjourChatServer];
	[_bonjourChatServer start];
    
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
   
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"sessionRunningAndDeviceAuthorized" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"sessionRunningAndDeviceAuthorized %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
     }];
    
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"shutdownCamSessionAndBonjourServer" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"shutdownCamSessionAndBonjourServer %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"sessionRunningAndDeviceRestarted" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"sessionRunningAndDeviceRestarted %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
     }];
    
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"mediaPlayerPlayingNotification" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"mediaPlayerPlayingNotification %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);

         _mediaPlayerPlaying = YES;
         _barButtonConnect.enabled = !_mediaPlayerPlaying;
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"mediaPlayerStoppingNotification" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"mediaPlayerStoppingNotification %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
         
         _mediaPlayerPlaying = NO;
         _barButtonConnect.enabled = !_mediaPlayerPlaying;

     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidEnterBackgroundNotification" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"UIApplicationDidEnterBackgroundNotification %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
         
         [self shutdown];
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationWillEnterForegroundNotification" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"UIApplicationWillEnterForegroundNotification %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
         
         [self restartCameraServer];
     }];
}

- (void) restartCameraServer {
    [[CameraServer sharedInstance] initWithCamViewController:self];
    [[CameraServer sharedInstance] restartSession];
}
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) connect:(NSNotification *)notification
{
    if ([_foundServices count]) {
        // other person's server
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        self.chatRoom = _foundServices[0];

        
        NSNetService *service = self.chatRoom;
		NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];
		NSString *roomName = [[NSString alloc] initWithData:dict[@"RoomName"] encoding:NSUTF8StringEncoding];
        NSString *roomIpAdress = [[NSString alloc] initWithData:dict[@"ipAdress"] encoding:NSUTF8StringEncoding];
        
        self.ipAdressOfOtherRoom = _foundServicesIpAdresses[0];
        self.otherVDLChatRoom = [[VDLViewController alloc]initWithData:self.ipAdressOfOtherRoom];
        [self addChildViewController:self.otherVDLChatRoom];
        [self.view addSubview:self.otherVDLChatRoom.view];
        self.otherVDLChatRoom.view.frame = self.view.bounds;
        
        [self.otherVDLChatRoom didMoveToParentViewController:self];
        });
        
        
    } else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:@"Info"
                                        message:@"no opened Other Room"
                                       delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil] show];
            
        });
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
#pragma mark - Storyboard

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    if ([[segue identifier] isEqualToString:@"ChatRoom"])
    {
        AVChatViewController *destination = (AVChatViewController *)[segue destinationViewController];
        if (0)
        {
            // own server
            destination.chatRoom = _createdRooms[0];
            destination.otherVDLChatRoom = nil;
            self.navigationItem.rightBarButtonItem.enabled = NO;//Disable new owner chat rooms
            //});
        }
        else
        {
            
            // other person's server
            destination.chatRoom = _foundServices[0];
            destination.ipAdressOfOtherRoom = _foundServicesIpAdresses[0];
            destination.otherVDLChatRoom = [[VDLViewController alloc]initWithData:destination.ipAdressOfOtherRoom];
            [destination addChildViewController:destination.otherVDLChatRoom];
            [destination.view addSubview:destination.otherVDLChatRoom.view];
            [destination.otherVDLChatRoom didMoveToParentViewController:destination];
            
        }
    }
    
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


- (BOOL)_isLocalServiceIdentifier:(NSString *)identifier
{
	for (BonjourChatServer *server in _createdRooms)
	{
		if ([server.identifier isEqualToString:identifier])
		{
			return YES;
		}
	}
	
	return NO;
}

- (void)_updateFoundServices
{
	BOOL didUpdate = NO;
	
	for (NSNetService *service in [_unidentifiedServices copy])
	{
		NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];
		
		if (!dict)
		{
			continue;
		}
		
		NSString *identifier = [[NSString alloc] initWithData:dict[@"ID"] encoding:NSUTF8StringEncoding];
        NSString *ipString = dict[@"ipAdress"];
        
		if (![self _isLocalServiceIdentifier:identifier])
		{
			[_foundServices addObject:service];
            [_foundServicesIpAdresses addObject:ipString];
            
			didUpdate = YES;
		}
		
		[_unidentifiedServices removeObject:service];
	}
	
	if (didUpdate)
	{
	//	[self.tableView reloadData];
	}
}


#pragma mark - NetServiceBrowser Delegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
           didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
	aNetService.delegate = self;
	[aNetService startMonitoring];
	
	[_unidentifiedServices addObject:aNetService];
	
	NSLog(@"found: %@", aNetService);
	
	if (!moreComing)
	{
		[self _updateFoundServices];
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
         didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
	[_foundServices removeObject:aNetService];
    
	[_unidentifiedServices removeObject:aNetService];
	
	NSLog(@"removed: %@", aNetService);
	
	if (!moreComing)
	{
		//[self.tableView reloadData];
	}
}

#pragma mark - NSNetService Delegate
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
	[self _updateFoundServices];
	
	[sender stopMonitoring];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    
}


- (IBAction)connectOther:(UIBarButtonItem *)sender {
    
    if ([_foundServices count]) {
        // other person's server
        self.chatRoom = _foundServices[0];
        self.ipAdressOfOtherRoom = _foundServicesIpAdresses[0];
        self.otherVDLChatRoom = [[VDLViewController alloc]initWithData:self.ipAdressOfOtherRoom];
        [self addChildViewController:self.otherVDLChatRoom];
        [self.view addSubview:self.otherVDLChatRoom.view];
        self.otherVDLChatRoom.view.frame = self.view.bounds;
        
        [self.otherVDLChatRoom didMoveToParentViewController:self];
        
     
    } else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:@"Info"
                                        message:@"no opened Other Room"
                                       delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil] show];

        });
    }
}
@end
