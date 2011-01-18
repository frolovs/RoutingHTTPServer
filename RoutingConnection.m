#import "RoutingConnection.h"
#import "RoutingHTTPServer.h"
#import "HTTPMessage.h"


@implementation RoutingConnection

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig {
	if (self = [super initWithAsyncSocket:newSocket configuration:aConfig]) {
		if (![config.server isKindOfClass:[RoutingHTTPServer class]]) {
			// Woah, badness
			// TODO: Log
			return self;
		}

		http = (RoutingHTTPServer *)config.server;
	}
	return self;
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path {

	if ([http supportsMethod:method])
		return YES;

	return [super supportsMethod:method atPath:path];
}

- (void)processDataChunk:(NSData *)postDataChunk {
	BOOL result = [request appendData:postDataChunk];
	if (!result) {
		// TODO: Log
	}
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
	NSURL *url = [request url];
	NSString *query = nil;
	NSDictionary *params = [NSDictionary dictionary];
	[headers release];
	headers = nil;

	if (url) {
		path = [url path]; // Strip the query string from the path
		query = [url query];
		if (query) {
			params = [self parseParams:query];
		}
	}

	RouteResponse *response = [http routeMethod:method withPath:path parameters:params request:request connection:self];
	if (response != nil) {
		headers = [response.headers retain];
		return response.response;
	}

	return [super httpResponseForMethod:method URI:path];
}

- (NSData *)preprocessResponse:(HTTPMessage *)response {
	[http.defaultHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
		[response setHeaderField:field value:value];
	}];

	if (headers) {
		[headers enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
			[response setHeaderField:field value:value];
		}];
	}

	// Set the connection header if not already specified
	NSString *connection = [response headerField:@"Connection"];
	if (!connection) {
		connection = [self shouldDie] ? @"close" : @"keep-alive";
		[response setHeaderField:@"Connection" value:connection];
	}

	return [super preprocessResponse:response];
}

@end
