//
//  ANSRequestMocker.h
//
//  Created by Avi Shevin on 27/10/2015.
//  Copyright © 2015 Avi Shevin. All rights reserved.
//
//  License: Free to use, as long as this comment header is unmodified.

#import <Foundation/Foundation.h>

extern NSString *const kANSFilterResponseStatusCode;
extern NSString *const kANSFilterResponseHTTPVersion;
extern NSString *const kANSFilterResponseHeaderFields;
extern NSString *const kANSFilterResponseHeaderContentType;

@class ANSRequestFilter;

typedef id(^ANSRequestFilterDataBlock)(ANSRequestFilter *filter, NSURLRequest *request);

@interface ANSRequestFilter : NSObject

@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *httpMethod;
@property (nonatomic, copy) ANSRequestFilterDataBlock dataBlock;
@property (nonatomic, copy) NSDictionary *responseDictionary;

@property (nonatomic, readonly) NSMutableDictionary *variables;

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
                  dataObject:(id)dataObject;

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
                   dataBlock:(ANSRequestFilterDataBlock)dataBlock;

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
          responseDictionary:(NSDictionary *)responseDictionary
                  dataObject:(id)dataObject;

- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
                  httpMethod:(NSString *)httpMethod
          responseDictionary:(NSDictionary *)responseDictionary
                   dataBlock:(ANSRequestFilterDataBlock)dataBlock;

@end

@interface ANSRequestMocker : NSURLProtocol

+ (void)registerFilters:(NSArray *)filters;

@end
