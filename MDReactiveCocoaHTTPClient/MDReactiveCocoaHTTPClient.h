//
//  MDReactiveCocoaHTTPClient.h
//  MDReactiveCocoaHTTPClient
//
//  Created by Jave on 2017/8/10.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for MDReactiveCocoaHTTPClient.
FOUNDATION_EXPORT double MDReactiveCocoaHTTPClientVersionNumber;

//! Project version string for MDReactiveCocoaHTTPClient.
FOUNDATION_EXPORT const unsigned char MDReactiveCocoaHTTPClientVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <MDReactiveCocoaHTTPClient/PublicHeader.h>

#import <AFNetworking/AFNetworking.h>
#import <ReactiveObjC/ReactiveObjC.h>
#import <MDReactiveCocoaHTTPClient/NSObject+MDSerialization.h>

extern NSString * const MDHTTPMethodGET;

extern NSString * const MDHTTPMethodPOST;

extern NSString * const MDHTTPMethodPUT;

extern NSString * const MDHTTPMethodDELETE;

extern NSString * const MDHTTPMethodHEAD;

extern NSString * const MDHTTPMethodPATCH;


@interface MDReactiveCocoaHTTPClient : AFHTTPSessionManager

@property (nonatomic, copy  , readonly) NSString *token;

+ (instancetype)unauthenticatedClientWithURL:(NSURL *)URL;

+ (instancetype)authenticatedClientWithURL:(NSURL *)URL token:(NSString *)token;

// undefine parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                            parameters:(id)parameters
                   parsedResponseBlock:(RACSignal *(^)(id result))parsedResponseBlock;

// undefine parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                              HTTPBody:(id)HTTPBody
                       queryParameters:(id)queryParameters
                   parsedResponseBlock:(RACSignal *(^)(id result))parsedResponseBlock;

// array or dictionary parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                            parameters:(id)parameters
                           resultClass:(Class)resultClass
                               keyPath:(NSString *)keyPath;

// array or dictionary parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                              HTTPBody:(id)HTTPBody
                       queryParameters:(id)queryParameters
                           resultClass:(Class)resultClass
                               keyPath:(NSString *)keyPath;

- (id)filterSuccessResponse:(NSURLSessionDataTask *)task responseObject:(id)responseObject error:(NSError **)error;
- (NSError *)filterFailureResponse:(NSURLSessionDataTask *)task responseObject:(id)responseObject error:(NSError *)error;

@end
