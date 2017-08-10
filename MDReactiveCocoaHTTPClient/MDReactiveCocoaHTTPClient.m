//
//  MDReactiveCocoaHTTPClient.m
//  MDReactiveCocoaHTTPClient
//
//  Created by Jave on 2017/8/10.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import "MDReactiveCocoaHTTPClient.h"
#import "NSObject+MDSerialization.h"

/**
 *  NULL 转换成 空NSString
 */
#define ntoe(string)                                       (string ? string : @"")

/**
 *  NSInteger 转换成 NSString
 */

#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE)|| TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
#define itos(integer)                                      [NSString stringWithFormat:@"%ld", (long)integer]
#define uitos(integer)                                      [NSString stringWithFormat:@"%lu", (unsigned long)integer]
#else
#define itos(integer)                                      [NSString stringWithFormat:@"%d", integer]
#define uitos(integer)                                      [NSString stringWithFormat:@"%u", integer]
#endif

NSString * const MDHTTPMethodGET        = @"GET";

NSString * const MDHTTPMethodPOST       = @"POST";

NSString * const MDHTTPMethodPUT        = @"PUT";

NSString * const MDHTTPMethodDELETE     = @"DELETE";

NSString * const MDHTTPMethodHEAD       = @"HEAD";

NSString * const MDHTTPMethodPATCH      = @"PATCH";

NSString * const MDReactiveCocoaHTTPClientAuthorizeURLString = @"validateMachineNumber";

@interface MDReactiveCocoaHTTPClient ()

@property (nonatomic, copy  ) NSString *token;

@end

@implementation MDReactiveCocoaHTTPClient

+ (instancetype)unauthenticatedClientWithURL:(NSURL *)URL {
    NSParameterAssert(URL != nil);
    MDReactiveCocoaHTTPClient *client = [[[self class] alloc] initWithURL:URL];
    return client;
}

+ (instancetype)authenticatedClientWithURL:(NSURL *)URL token:(NSString *)token {
    NSParameterAssert(URL != nil);
    NSParameterAssert(token != nil);
    MDReactiveCocoaHTTPClient *client = [[[self class] alloc] initWithURL:URL];
    client.token = token;
    return client;
}

- (id)initWithURL:(NSURL *)URL {
    NSParameterAssert(URL != nil);
    self = [self initWithBaseURL:URL];
    if (self) {
        self.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
    }
    return self;
}

#pragma mark Class Properties

- (id)filterSuccessResponse:(NSURLSessionDataTask *)task responseObject:(id)responseObject error:(NSError **)error{
    if ([responseObject isKindOfClass:[NSArray class]] || [responseObject isKindOfClass:[NSDictionary class]]) {
        responseObject =  [responseObject filterNullObject];
    }
    return responseObject;
}

- (NSError *)filterFailureResponse:(NSURLSessionDataTask *)task responseObject:(id)responseObject error:(NSError *)error{
    return error;
}

- (NSURLSessionDataTask *)dataTaskWithURLString:(NSString *)URLString
                                     HTTPMethod:(NSString *)method
                                       HTTPBody:(id)HTTPBody
                                queryParameters:(id)queryParameters
                                        success:(void (^)(NSURLSessionDataTask *, id))success
                                        failure:(void (^)(NSURLSessionDataTask *, NSError *, id))failure {
    
    NSError *serializationError = nil;
    NSMutableURLRequest *mutableRequest = [[self requestSerializer] requestWithMethod:method URLString:[[NSURL URLWithString:URLString relativeToURL:[self baseURL]] absoluteString] parameters:HTTPBody error:&serializationError];
    NSString *query = AFQueryStringFromParameters(queryParameters);
    if ([query length]) {
        mutableRequest.URL = [NSURL URLWithString:[[[mutableRequest URL] absoluteString] stringByAppendingFormat:[[mutableRequest URL] query] ? @"&%@" : @"?%@", query]];
    }
    if (serializationError) {
        if (failure) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError, nil);
            });
#pragma clang diagnostic pop
        }
        return nil;
    }
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:mutableRequest
                       completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
                           if (error) {
                               if (failure) {
                                   failure(dataTask, responseObject, error);
                               }
                           } else {
                               if (success) {
                                   success(dataTask, responseObject);
                               }
                           }
                       }];
    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                         success:(void (^)(NSURLSessionDataTask *, id))success
                                         failure:(void (^)(NSURLSessionDataTask *, NSError *, id))failure {
    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:parameters error:&serializationError];
    if (serializationError) {
        if (failure) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError, nil);
            });
#pragma clang diagnostic pop
        }
        return nil;
    }
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:request
                       completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
                           if (error) {
                               if (failure) {
                                   failure(dataTask, error, responseObject);
                               }
                           } else {
                               if (success) {
                                   success(dataTask, responseObject);
                               }
                           }
                       }];
    [dataTask resume];
    return dataTask;
}

- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                              HTTPBody:(id)HTTPBody
                       queryParameters:(id)queryParameters;{
    @weakify(self);
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        NSURLSessionDataTask *dataTask = nil;
        if ([HTTPMethod isEqualToString:MDHTTPMethodPOST] || [HTTPMethod isEqualToString:MDHTTPMethodPUT]) {
            dataTask = [self dataTaskWithURLString:URLString HTTPMethod:HTTPMethod HTTPBody:HTTPBody queryParameters:queryParameters success:^(NSURLSessionDataTask * task, id responseObject){
                @strongify(self);
                NSError *error = nil;
                responseObject = [self filterSuccessResponse:task responseObject:responseObject error:&error];
                if (!error) {
                    [[RACSignal return:RACTuplePack(task, responseObject)] subscribe:subscriber];
                } else {
                    [subscriber sendError:error];
                }
            } failure:^(NSURLSessionDataTask * task, NSError *error, id responseObject){
                @strongify(self);
                [subscriber sendError:[self filterFailureResponse:task responseObject:responseObject error:error]];
            }];
        }
        if (dataTask) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(self);
                NSLog(@"begin http task : %@  \nrequest : %@ \nHTTPBody: %@ \nqueryParameters : \n%@ \nheaderParameters : \n%@", [dataTask description], [[dataTask currentRequest] description], HTTPBody, queryParameters, [[self requestSerializer] HTTPRequestHeaders]);
            });
        }
        return [RACDisposable disposableWithBlock:^{
            [dataTask cancel];
        }];
    }];
}

- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                            parameters:(id)parameters;{
    @weakify(self);
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:HTTPMethod URLString:URLString parameters:parameters success:^(NSURLSessionDataTask * task, id responseObject){
            @strongify(self);
            NSError *error = nil;
            responseObject = [self filterSuccessResponse:task responseObject:responseObject error:&error];
            if (!error) {
                [[RACSignal return:RACTuplePack(task, responseObject)] subscribe:subscriber];
            } else {
                [subscriber sendError:error];
            }
        } failure:^(NSURLSessionDataTask * task, NSError *error, id responseObject){
            @strongify(self);
            [subscriber sendError:[self filterFailureResponse:task responseObject:responseObject error:error]];
        }];
        if (dataTask) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(self);
                NSLog(@"begin http task : %@  \nrequest : %@ \nparameters : \n%@ \nheaderParameters : \n%@", [dataTask description], [[dataTask currentRequest] description], parameters, [[self requestSerializer] HTTPRequestHeaders]);
            });
        }
        return [RACDisposable disposableWithBlock:^{
            if (dataTask) {
                [dataTask cancel];
            }
        }];
    }];
}

// undefine parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                            parameters:(id)parameters
                   parsedResponseBlock:(RACSignal *(^)(id result))parsedResponseBlock{
    @weakify(self);
    return [[[self taskSignalWithURLString:URLString HTTPMethod:HTTPMethod parameters:parameters] reduceEach:^id(NSURLSessionTask *task, id result){
        @strongify(self);
        return [self parsedResponse:result block:parsedResponseBlock];
    }] concat];
}

// undefine parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                              HTTPBody:(id)HTTPBody
                       queryParameters:(id)queryParameters
                   parsedResponseBlock:(RACSignal *(^)(id result))parsedResponseBlock{
    @weakify(self);
    return [[[self taskSignalWithURLString:URLString HTTPMethod:HTTPMethod HTTPBody:HTTPBody queryParameters:queryParameters] reduceEach:^id(NSURLSessionTask *task, id result){
        @strongify(self);
        return [self parsedResponse:result block:parsedResponseBlock];
    }] concat];
}

// array or dictionary parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                            parameters:(id)parameters
                           resultClass:(Class)resultClass
                               keyPath:(NSString *)keyPath{
    @weakify(self);
    return [[[self taskSignalWithURLString:URLString HTTPMethod:HTTPMethod parameters:parameters] reduceEach:^id(NSURLSessionTask *task, id result){
        @strongify(self);
        return [self parsedResponseOfClass:resultClass keyPath:keyPath fromJSON:result];
    }] concat];
}

// array or dictionary parse action
- (RACSignal *)taskSignalWithURLString:(NSString *)URLString
                            HTTPMethod:(NSString *)HTTPMethod
                              HTTPBody:(id)HTTPBody
                       queryParameters:(id)queryParameters
                           resultClass:(Class)resultClass
                               keyPath:(NSString *)keyPath{
    @weakify(self);
    return [[[self taskSignalWithURLString:URLString HTTPMethod:HTTPMethod HTTPBody:HTTPBody queryParameters:queryParameters] reduceEach:^id(NSURLSessionTask *task, id result){
        @strongify(self);
        return [self parsedResponseOfClass:resultClass keyPath:keyPath fromJSON:result];
    }] concat];
}

- (NSString *)stringValueFromObject:(id)value{
    if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
        return [value JSONString];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else {
        return [value description];
    }
}

- (RACSignal *)parsedResponse:(id)response block:(RACSignal *(^)(id result))parsedResponseBlock{
    return [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
        RACDisposable *disposable = [(parsedResponseBlock ? parsedResponseBlock(response) : [RACSignal return:response]) subscribe:subscriber];
        [subscriber sendCompleted];
        return [RACDisposable disposableWithBlock:^{
            [disposable dispose];
        }];
    }];
}

- (RACSignal *)parsedResponseOfClass:(Class)resultClass keyPath:(NSString *)keyPath fromJSON:(id)responseObject {
    //    NSParameterAssert(resultClass == nil || [resultClass isSubclassOfClass:[MTLModel class]]);
    @weakify(self);
    return [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
        void (^parseJSONDictionary)(NSDictionary *) = ^(NSDictionary *JSONDictionary) {
            @strongify(self);
            void (^adapteJOSNModel)(NSDictionary *JSONValue) = ^(NSDictionary *JSONValue){
                NSError *error = nil;
                id parsedObject = [JSONValue modelOfClass:resultClass error:&error];
                if (parsedObject == nil) {
                    // Don't treat "no class found" errors as real parsing failures.
                    // In theory, this makes parsing code forward-compatible with
                    // API additions.
                    if (error) {
                        NSLog(@"Parsed model failed : %@   \n JOSN : %@", error, responseObject);
                        [subscriber sendError:error];
                    }
                    return;
                }
                [subscriber sendNext:parsedObject];
            };
            id JSONValue = JSONDictionary;
            if ([JSONValue isKindOfClass:[NSDictionary class]] && [keyPath length]) {
                JSONValue = [JSONDictionary valueForKeyPath:keyPath];
            }
            if (resultClass == nil) {
                [subscriber sendNext:JSONValue];
                return;
            }
            if (![JSONValue isKindOfClass:[NSArray class]]) {
                if (resultClass == [NSString class]) {
                    [subscriber sendNext:[self stringValueFromObject:JSONValue]];
                    return;
                }
                if (resultClass == [NSNumber class]) {
                    [subscriber sendNext:[[NSNumberFormatter new] numberFromString:[self stringValueFromObject:JSONValue]]];
                    return ;
                }
                adapteJOSNModel(JSONValue);
            } else {
                for (NSDictionary *subJSONValue in JSONValue) {
                    if (![subJSONValue isKindOfClass:[NSDictionary class]]) {
                        [subscriber sendNext:JSONValue];
                        return ;
                    }
                    adapteJOSNModel(subJSONValue);
                }
            }
        };
        if ([responseObject isKindOfClass:[NSArray class]]) {
            for (NSDictionary *JSONDictionary in responseObject) {
                if (![JSONDictionary isKindOfClass:[NSDictionary class]]) {
                    [subscriber sendNext:responseObject];
                    return nil;
                }
                parseJSONDictionary(JSONDictionary);
            }
            [subscriber sendCompleted];
        } else if ([responseObject isKindOfClass:[NSDictionary class]]) {
            parseJSONDictionary(responseObject);
            [subscriber sendCompleted];
        } else {
            [subscriber sendNext:responseObject];
            [subscriber sendCompleted];
        }
        return nil;
    }];
}

@end
