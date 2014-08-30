//
//  ChatRoomTableViewController.m
//  BonjourChat
//
//  Created by Oliver Drobnik on 04.11.12.
//  Copyright (c) 2012 Oliver Drobnik. All rights reserved.
//

#import "ChatRoomTableViewController.h"
#import "RoomCreationViewController.h"
#import "BonjourChatServer.h"
#import "ChatTableViewController.h"
#import "AVChatViewController.h"
#include <sys/socket.h>
#include <netinet/in.h>
#import <arpa/inet.h>
#import "VDLViewController.h"
#import "AppDelegate.h"

#define debug


extern void * SessionRunningAndDeviceAuthorizedContext;


@interface ChatRoomTableViewController() <RoomCreationViewControllerDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@end


@implementation ChatRoomTableViewController
{
	NSMutableSet *_unidentifiedServices;
	NSMutableArray *_foundServices;
	NSMutableArray *_createdRooms;
	NSNetServiceBrowser *_serviceBrowser;
    NSMutableArray *_foundServicesIpAdresses;
    AVChatViewController *_destination;
    BonjourChatServer *_bonjourChatServer;
}


//- (void)receiveSessionRunningAndDeviceAuthorizedNotification:(NSNotification *) notification
//{
//    NSLog(@"%@", [notification.object class]);
//}
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;   // iOS 7 specific
    }
    
    
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"sessionRunningAndDeviceAuthorized" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"sessionRunningAndDeviceAuthorized %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
         
         
         
         // ...
     }];
    
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"shutdownCamSessionAndBonjourServer" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"shutdownCamSessionAndBonjourServer %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
         
         
         // ...
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"sessionRunningAndDeviceRestarted" object:nil queue:mainQueue
                                                  usingBlock:^(NSNotification *notification)
     {
         NSString *message = [NSString stringWithFormat:@"sessionRunningAndDeviceRestarted %@ ", __AppDelegate.deviceType];
         NSLog(@"%@", message);
         
         
         // ...
     }];
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
		[self.tableView reloadData];
	}
}


#pragma mark - Storyboard

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    if ([[segue identifier] isEqualToString:@"CreateChatRoom"])
    {
        RoomCreationViewController *destination = (RoomCreationViewController *)[[segue destinationViewController] topViewController];
        destination.delegate = self;
    }
    else 	if ([[segue identifier] isEqualToString:@"ChatRoom"])
    {
        _destination = (AVChatViewController *)[segue destinationViewController];
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        
        if (indexPath.section==0)
        {
            // own server
            _destination.chatRoom = _createdRooms[indexPath.row];
            _destination.otherVDLChatRoom = nil;
            self.navigationItem.rightBarButtonItem.enabled = NO;//Disable new owner chat rooms
            //});
        }
        else
        {
            
            // other person's server
            _destination.chatRoom = _foundServices[indexPath.row];
            _destination.ipAdressOfOtherRoom = _foundServicesIpAdresses[indexPath.row];
            _destination.otherVDLChatRoom = [[VDLViewController alloc]initWithData:_destination.ipAdressOfOtherRoom];
            [_destination addChildViewController:_destination.otherVDLChatRoom];
            [_destination.view addSubview:_destination.otherVDLChatRoom.view];
            [_destination.otherVDLChatRoom didMoveToParentViewController:_destination];
            
            
        }
    }
    
}


void runOnMainQueueWithoutDeadlocking(void (^block)(void))
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

//- (void)ipAdressAndPort:(NSNetService *)service // not working
//{
//    char addressBuffer[INET6_ADDRSTRLEN];
//
//    for (NSData *data in service.addresses)
//    {
//        memset(addressBuffer, 0, INET6_ADDRSTRLEN);
//
//        typedef union {
//            struct sockaddr sa;
//            struct sockaddr_in ipv4;
//            struct sockaddr_in6 ipv6;
//        } ip_socket_address;
//
//        ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];
//
//        if (socketAddress && (socketAddress->sa.sa_family == AF_INET || socketAddress->sa.sa_family == AF_INET6))
//        {
//            const char *addressStr = inet_ntop(
//                                               socketAddress->sa.sa_family,
//                                               (socketAddress->sa.sa_family == AF_INET ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
//                                               addressBuffer,
//                                               sizeof(addressBuffer));
//
//            int port = ntohs(socketAddress->sa.sa_family == AF_INET ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);
//
//            if (addressStr && port)
//            {
//                NSLog(@"Found service at %s:%d", addressStr, port);
//            }
//        }
//    }
//}

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
		[self.tableView reloadData];
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

#pragma mark - RoomCreationTableViewController Delegate

- (void)roomCreationViewControllerDidSave:(RoomCreationViewController *)roomCreationViewController
{
	_bonjourChatServer = [[BonjourChatServer alloc] initWithRoomName:roomCreationViewController.roomNameField.text];
	[_createdRooms addObject:_bonjourChatServer];
	[_bonjourChatServer start];
    
	[self dismissViewControllerAnimated:YES completion:NULL];
    [self performSegueWithIdentifier:@"ChatRoom" sender:self];
    
    [self.tableView reloadData];
}

- (void)roomCreationViewControllerDidCancel:(RoomCreationViewController *)roomCreationViewController
{
	[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITableView Delegate / Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
	{
		return @"My Rooms";
	}
	
	return @"Other People's Rooms";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
	{
		return [_createdRooms count];
	}
	
	return [_foundServices count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatRoomCell"];
    cell.userInteractionEnabled = YES;
    cell.textLabel.enabled = YES;
    
	if (indexPath.section == 0)
	{
		BonjourChatServer *server = _createdRooms[indexPath.row];
		cell.textLabel.text = server.roomName;
		cell.detailTextLabel.text = nil;
	}
	else
	{
		NSNetService *service = _foundServices[indexPath.row];
		
		NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];
		NSString *roomName = [[NSString alloc] initWithData:dict[@"RoomName"] encoding:NSUTF8StringEncoding];
        NSString *roomIpAdress = [[NSString alloc] initWithData:dict[@"ipAdress"] encoding:NSUTF8StringEncoding];
#if defined ( debug )
        NSString*txtLabel = [NSString stringWithFormat:@"%@ at %@", roomName, roomIpAdress];
#else
        NSString*txtLabel = roomName;
#endif
		cell.textLabel.text = txtLabel;
		cell.detailTextLabel.text = [service name];
        if ([_createdRooms count]==0)
        {
            cell.userInteractionEnabled = NO;
            cell.textLabel.enabled = NO;
            
        }
	}
	
	return cell;
}

@end
