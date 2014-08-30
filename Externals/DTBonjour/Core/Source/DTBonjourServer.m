//
//  DTBonjourServer.m
//  DTBonjour
//
//  Created by Oliver Drobnik on 01.11.12.
//  Copyright (c) 2012 Oliver Drobnik. All rights reserved.
//

#import "DTBonjourServer.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>

#import <CoreFoundation/CoreFoundation.h>

#import "DTBonjourDataConnection.h"
#import "DTBonjourDataChunk.h"
#import "AppDelegate.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
#import "AVChatViewController.h"
#import "CameraServer.h"

@interface DTBonjourServer() <NSNetServiceDelegate, DTBonjourDataConnectionDelegate>

- (void)_acceptConnection:(CFSocketNativeHandle)nativeSocketHandle ipAdress:(NSString*)ipString port:(int)port;
@end

// call-back function for incoming connections
static void ListeningSocketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
	DTBonjourServer *server = (__bridge DTBonjourServer *)info;
	
	const struct sockaddr *sa = (const struct sockaddr *)CFDataGetBytePtr(address);
	
	sa_family_t family = sa->sa_family;
	
	NSString *ipString = nil;
	NSString *familyString = nil;
	NSUInteger port = 0;
	
	if (family == AF_INET)
	{
		familyString = @"IPv4";
		
		struct sockaddr_in addr4;
		CFDataGetBytes(address, CFRangeMake(0, sizeof(addr4)), (void *)&addr4);
		
		char str[INET_ADDRSTRLEN];
		inet_ntop(AF_INET, &(addr4.sin_addr), str, INET_ADDRSTRLEN);
		ipString = [[NSString alloc] initWithBytes:str length:strlen(str) encoding:NSUTF8StringEncoding];
		
		port = ntohs(addr4.sin_port);
	}
	else if (family == AF_INET6)
	{
		familyString = @"IPv6";
		
		struct sockaddr_in6 addr6;
		CFDataGetBytes(address, CFRangeMake(0, sizeof(addr6)), (void *)&addr6);
		
		char str[INET6_ADDRSTRLEN];
		inet_ntop(AF_INET6, &(addr6.sin6_addr), str, INET6_ADDRSTRLEN);
		ipString = [[NSString alloc] initWithBytes:str length:strlen(str) encoding:NSUTF8StringEncoding];
		
		port = ntohs(addr6.sin6_port);
	}
	
	NSLog(@"Accepting %@ connection from %@ on port %d", familyString, ipString, (int)port);
    NSLog(@"%@", __AppDelegate.deviceType);

	// For an accept callback, the data parameter is a pointer to a CFSocketNativeHandle.
	[server _acceptConnection:*(CFSocketNativeHandle *)data ipAdress:ipString port:(int)port];

}


@implementation DTBonjourServer
{
	NSNetService *_service;
	NSDictionary *_TXTRecord;
	
	CFSocketRef _ipv4socket;
	CFSocketRef _ipv6socket;
	
	NSUInteger _port; // used port, assigned during start
	
	NSMutableSet *_connections;
	NSString *_bonjourType;
	
	__weak id <DTBonjourServerDelegate> _delegate;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
		if (![_bonjourType length])
		{
			return nil;
		}
		
		_connections = [[NSMutableSet alloc] init];
		
#if TARGET_OS_IPHONE
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
	}
	
	return self;
}

- (id)initWithBonjourType:(NSString *)bonjourType
{
	if (!bonjourType)
	{
		return nil;
	}
	
	_bonjourType = bonjourType;
	
	self = [self init];
	
	if (self)
	{
		
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	_delegate = nil;

	[self stop];
}

- (BOOL)start
{
	assert(_ipv4socket == NULL && _ipv6socket == NULL);       // don't call -start twice!
	
	CFSocketContext socketCtxt = {0, (__bridge void *) self, NULL, NULL, NULL};
	_ipv4socket = CFSocketCreate(kCFAllocatorDefault, AF_INET,  SOCK_STREAM, 0, kCFSocketAcceptCallBack, &ListeningSocketCallback, &socketCtxt);
	_ipv6socket = CFSocketCreate(kCFAllocatorDefault, AF_INET6, SOCK_STREAM, 0, kCFSocketAcceptCallBack, &ListeningSocketCallback, &socketCtxt);
	
	if (NULL == _ipv4socket || NULL == _ipv6socket)
	{
		[self stop];
		return NO;
	}
	
	static const int yes = 1;
	(void) setsockopt(CFSocketGetNative(_ipv4socket), SOL_SOCKET, SO_REUSEADDR, (const void *) &yes, sizeof(yes));
	(void) setsockopt(CFSocketGetNative(_ipv6socket), SOL_SOCKET, SO_REUSEADDR, (const void *) &yes, sizeof(yes));
	
	// Set up the IPv4 listening socket; port is 0, which will cause the kernel to choose a port for us.
	struct sockaddr_in addr4;
	memset(&addr4, 0, sizeof(addr4));
	addr4.sin_len = sizeof(addr4);
	addr4.sin_family = AF_INET;
	addr4.sin_port = htons(0);
	addr4.sin_addr.s_addr = htonl(INADDR_ANY);
	
	if (kCFSocketSuccess != CFSocketSetAddress(_ipv4socket, (__bridge CFDataRef) [NSData dataWithBytes:&addr4 length:sizeof(addr4)]))
	{
		[self stop];
		return NO;
	}
	
	// Now that the IPv4 binding was successful, we get the port number
	// -- we will need it for the IPv6 listening socket and for the NSNetService.
	NSData *addr = (__bridge_transfer NSData *)CFSocketCopyAddress(_ipv4socket);
	assert([addr length] == sizeof(struct sockaddr_in));
	_port = ntohs(((const struct sockaddr_in *)[addr bytes])->sin_port);
	
	// Set up the IPv6 listening socket.
	struct sockaddr_in6 addr6;
	memset(&addr6, 0, sizeof(addr6));
	addr6.sin6_len = sizeof(addr6);
	addr6.sin6_family = AF_INET6;
	addr6.sin6_port = htons(self.port);
	memcpy(&(addr6.sin6_addr), &in6addr_any, sizeof(addr6.sin6_addr));
	if (kCFSocketSuccess != CFSocketSetAddress(_ipv6socket, (__bridge CFDataRef) [NSData dataWithBytes:&addr6 length:sizeof(addr6)]))
	{
		[self stop];
		return NO;
	}
	
	// Set up the run loop sources for the sockets.
	CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _ipv4socket, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source4, kCFRunLoopCommonModes);
	CFRelease(source4);
	
	CFRunLoopSourceRef source6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _ipv6socket, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source6, kCFRunLoopCommonModes);
	CFRelease(source6);
	
	if (_ipv6socket)
	{
		CFSocketInvalidate(_ipv6socket);
		CFRelease(_ipv6socket);
		_ipv6socket = NULL;
	}
	
	assert(self.port > 0 && self.port < 65536);
	_service = [[NSNetService alloc] initWithDomain:@"" type:_bonjourType name:@"" port:(int)_port];
	_service.delegate = self;
	
	if (_TXTRecord)
	{
		[_service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:_TXTRecord]];
	}
	
	[_service publishWithOptions:0];
	
	return YES;
}


- (void)stop
{
	// stop the bonjour advertising
	[_service stop];
	_service = nil;
	
	// Closes all the open connections.  The EchoConnectionDidCloseNotification notification will ensure
	// that the connection gets removed from the self.connections set.  To avoid mututation under iteration
	// problems, we make a copy of that set and iterate over the copy.
	for (DTBonjourDataConnection *connection in [_connections copy])
	{
		[connection close];
	}
	
	if (_ipv4socket)
	{
		CFSocketInvalidate(_ipv4socket);
		CFRelease(_ipv4socket);
		_ipv4socket = NULL;
	}
	
	if (_ipv6socket)
	{
		CFSocketInvalidate(_ipv6socket);
		CFRelease(_ipv6socket);
		_ipv6socket = NULL;
	}
    
    if (_delegate && [_delegate isKindOfClass:[AVChatViewController class]]) {
        NSLog(@"shutdown all...");
        [(AVChatViewController*)_delegate shutdown];
    }
}

- (void)_acceptConnection:(CFSocketNativeHandle)nativeSocketHandle ipAdress:(NSString*)ipString port:(int)port
{
	DTBonjourDataConnection *newConnection = [[DTBonjourDataConnection alloc] initWithNativeSocketHandle:nativeSocketHandle];
	newConnection.delegate = self;
	[newConnection open];
	[_connections addObject:newConnection];
	
	if ([_delegate respondsToSelector:@selector(bonjourServer:didAcceptConnection:ipAdress:port:)])
	{
		[_delegate bonjourServer:self didAcceptConnection:newConnection ipAdress:ipString port:(int)port];
	}
}

- (void)broadcastObject:(id)object
{
	for (DTBonjourDataConnection *connection in _connections)
	{
		NSError *error;
		
		if (![connection sendObject:object error:&error])
		{
			NSLog(@"%@", [error localizedDescription]);
		}
	}
}

#pragma mark - NSNetService Delegate

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
	NSLog(@"netService:didNotPublish -> Error publishing: %@", errorDict);
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
	NSLog(@"netServiceDidPublish -> My name: %@ port: %d", [sender name], (int)sender.port);
}

- (void)netServiceDidStop:(NSNetService *)sender
{
	NSLog(@"netServiceDidStop -> Bonjour Service shut down");
}

#pragma mark - DTBonjourDataConnection Delegate
- (void)connection:(DTBonjourDataConnection *)connection didReceiveObject:(id)object
{
	if ([_delegate respondsToSelector:@selector(bonjourServer:didReceiveObject:onConnection:)])
	{
		[_delegate bonjourServer:self didReceiveObject:object onConnection:connection];
	}
}

- (void)connectionDidClose:(DTBonjourDataConnection *)connection
{
	[_connections removeObject:connection];
}

#pragma mark - Notifications

- (void)appDidEnterBackground:(NSNotification *)notification
{
	[self stop];
}

- (void)appWillEnterForeground:(NSNotification *)notification
{
	[self start];
    
    if (_delegate && [_delegate isKindOfClass:[AVChatViewController class]]) {
        NSLog(@"restarting all...");
        [[CameraServer sharedInstance] initWithCamViewController:(AVChatViewController*)_delegate];
        [[CameraServer sharedInstance] restartSession];
    }
}

#pragma mark - Properties

- (NSSet *)connections
{
	// make a copy to be non-mutable
	return [_connections copy];
}

- (void)setTXTRecord:(NSDictionary *)TXTRecord
{
	_TXTRecord = TXTRecord;

	// update service if it is running
	if (_service)
	{
		[_service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:_TXTRecord]];
	}
}

@synthesize TXTRecord = _TXTRecord;
@synthesize delegate = _delegate;
@synthesize port = _port;

@end
