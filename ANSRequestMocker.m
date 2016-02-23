//
//  ANSRequestMocker.m
//
//  Created by Avi Shevin on 27/10/2015.
//  Copyright © 2015 Avi Shevin. All rights reserved.
//
//  License: Free to use, as long as this comment header is unmodified.

#import "ANSRequestMocker.h"

NSString *const kANSFilterResponseStatusCode = @"statusCode";
NSString *const kANSFilterResponseHTTPVersion = @"httpVersion";
NSString *const kANSFilterResponseHeaderFields = @"headerFields";
NSString *const kANSFilterResponseHeaderContentType = @"Content-Type";

@interface ANSRequestFilter()

@property (nonatomic, readwrite) NSMutableDictionary *variables;

@end

@implementation ANSRequestFilter

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
                  dataObject:(id)dataObject {
    return [self initWithHost:host path:path httpMethod:httpMethod responseDictionary:nil dataObject:dataObject];
}

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
                   dataBlock:(ANSRequestFilterDataBlock)dataBlock {
    return [self initWithHost:host
                         path:path
                   httpMethod:(NSString *)httpMethod
           responseDictionary:nil
                    dataBlock:dataBlock];
}

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
          responseDictionary:(NSDictionary *)responseDictionary
                   dataBlock:(ANSRequestFilterDataBlock)dataBlock {
    self = [super init];
    if ( self != nil ) {
        _host = [host copy];
        _path = [path copy];
        _httpMethod = [httpMethod copy];
        _dataBlock = [dataBlock copy];
        _responseDictionary = [responseDictionary copy];
    }
    return self;
}

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
          responseDictionary:(NSDictionary *)responseDictionary
                  dataObject:(id)dataObject {
    // Assume JSON.
    if ( [dataObject isKindOfClass:[NSDictionary class]] ) {
        dataObject = [NSJSONSerialization dataWithJSONObject:dataObject options:0 error:NULL];

        NSMutableDictionary *rd = [responseDictionary mutableCopy] ?: [NSMutableDictionary dictionary];
        NSMutableDictionary *h = [rd[kANSFilterResponseHeaderFields] mutableCopy] ?: [NSMutableDictionary dictionary];

        h[kANSFilterResponseHeaderContentType] = @"application/json";

        rd[kANSFilterResponseHeaderFields] = [h copy];
        responseDictionary = [rd copy];
    }

    return [self initWithHost:host
                         path:path
                   httpMethod:(NSString *)httpMethod
           responseDictionary:responseDictionary
                    dataBlock:^id(ANSRequestFilter *filter, NSURLRequest *request) {
                        return dataObject;
                    }];
}

#pragma mark -

- (BOOL)matchesRequest:(NSURLRequest *)request {
    NSURLComponents *comps = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];

    if ( [comps.host isEqualToString:_host] == NO ) {
        return NO;
    }

    if ( [request.HTTPMethod isEqualToString:_httpMethod] == NO ) {
        return NO;
    }

    NSArray *filterPathComps = [_path componentsSeparatedByString:@"/"];
    NSArray *requestPathComps = [comps.path componentsSeparatedByString:@"/"];

    if ( [[_path substringToIndex:1] isEqualToString:@"/"] ) {
        filterPathComps = [filterPathComps subarrayWithRange:NSMakeRange(1, filterPathComps.count - 1)];
    }

    if ( [[comps.path substringToIndex:1] isEqualToString:@"/"] ) {
        requestPathComps = [requestPathComps subarrayWithRange:NSMakeRange(1, requestPathComps.count - 1)];
    }

    if ( filterPathComps.count == 1 && [filterPathComps.lastObject isEqualToString:@"*"] ) {
        return YES;
    }

    if ( filterPathComps.count != requestPathComps.count ) {
        return NO;
    }

    __block BOOL matches = YES;

    NSRegularExpression *varRegEx = [NSRegularExpression regularExpressionWithPattern:@"\\$\\{(.*)\\}" options:0 error:NULL];

    [filterPathComps enumerateObjectsUsingBlock:^(NSString * _Nonnull filterComp, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *requestComp = requestPathComps[idx];

        NSArray *varMatches = [varRegEx matchesInString:filterComp options:0 range:NSMakeRange(0, filterComp.length)];
        if ( varMatches.count > 0 ) {
            _variables = ( _variables ) ?: [NSMutableDictionary dictionary];
            _variables[[filterComp substringWithRange:[varMatches.firstObject rangeAtIndex:1]]] = requestComp;

            return;
        }

        if ( [filterComp isEqualToString:@"*"] == NO && [filterComp isEqualToString:requestComp] == NO ) {
            matches = NO;
            *stop = YES;
        }
    }];

    return matches;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p> { host = %@; path = %@; method = %@ }",
            NSStringFromClass([self class]), self, _host, _path, _httpMethod];
}

@end

#pragma mark - ANSRequestMocker

static NSArray *registeredFilters;

@interface ANSRequestMocker()

@end

@implementation ANSRequestMocker

+ (void)registerFilters:(NSArray *)filters {
    registeredFilters = filters;
}

+ (ANSRequestFilter *)matchingFilterForRequest:(NSURLRequest *)request {
    __block ANSRequestFilter *match = nil;

    [registeredFilters enumerateObjectsUsingBlock:^(ANSRequestFilter * _Nonnull filter, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( [filter matchesRequest:request] ) {
            match = filter;
            *stop = YES;
        }
    }];

    return match;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSURLComponents *comps = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];

    return ( ( [comps.scheme isEqualToString:@"http"] || [comps.scheme isEqualToString:@"https"] ) &&
            [self matchingFilterForRequest:request] != nil );
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    ANSRequestFilter *match = [self matchingFilterForRequest:request];

    if ( match != nil ) {
        NSLog(@"Matching filter: %@", match);

        NSMutableURLRequest *req = [request mutableCopy];

        [NSURLProtocol setProperty:match forKey:@"filter" inRequest:req];

        request = [req copy];
    }

    return request;
}

- (void)startLoading {
    ANSRequestFilter *filter = [NSURLProtocol propertyForKey:@"filter" inRequest:self.request];

    NSData *data = ( filter.dataBlock != nil ) ? filter.dataBlock(filter, self.request) : nil;

    NSDictionary *responseDictionary = filter.responseDictionary;
    NSInteger statusCode = [responseDictionary[kANSFilterResponseStatusCode] integerValue];
    NSString *httpVersion = ( responseDictionary[kANSFilterResponseHTTPVersion] ) ?: @"HTTP/1.1";
    NSMutableDictionary *headers = [responseDictionary[kANSFilterResponseHeaderFields] mutableCopy] ?: [NSMutableDictionary dictionary];

    statusCode = ( statusCode ) ?: 200;

    headers[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)data.length];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:statusCode
                                                             HTTPVersion:httpVersion
                                                            headerFields:headers];
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {

}

@end
