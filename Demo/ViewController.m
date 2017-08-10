//
//  ViewController.m
//  Demo
//
//  Created by Jave on 2017/8/10.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import "ViewController.h"
#import <MDReactiveCocoaHTTPClient/MDReactiveCocoaHTTPClient.h>

NSString * const MDReactiveCocoaHTTPClientTestURLString = @"https://www.baidu.com";

@implementation MDReactiveCocoaHTTPClient (MDReactiveCocoaHTTPClientTest)

//https://www.baidu.com/home/news/data/newspage?nid=3418272174308104977&n_type=0&p_from=1&dtype=-1
- (RACSignal *)testWithNID:(NSString *)NID nType:(NSInteger)nType from:(NSInteger)from dType:(NSInteger)dType{
    return [self taskSignalWithURLString:@"/home/news/data/newspage" HTTPMethod:MDHTTPMethodPOST parameters:@{@"nid":NID, @"p_from": @(from), @"n_type": @(nType), @"dtype": @(dType)} resultClass:nil keyPath:nil];
}

@end

@interface MDStringResponseSerializer : AFHTTPResponseSerializer
@end

@implementation MDStringResponseSerializer

- (instancetype)init {
    if (self = [super init]) {
        self.acceptableContentTypes = [[NSSet alloc] initWithObjects:@"text/html", nil];
    }
    return self;
}

- (nullable id)responseObjectForResponse:(nullable NSURLResponse *)response
                                    data:(nullable NSData *)data
                                   error:(NSError **)error;{
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIWebView *webView;

@property (nonatomic, strong) MDReactiveCocoaHTTPClient *client;

@end

@implementation ViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    if (self = [super initWithCoder:aDecoder]) {
        self.client = [MDReactiveCocoaHTTPClient unauthenticatedClientWithURL:[NSURL URLWithString:MDReactiveCocoaHTTPClientTestURLString]];
        self.client.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:@[[MDStringResponseSerializer serializer], [AFJSONResponseSerializer serializer]]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[[self client] testWithNID:@"3418272174308104977" nType:0 from:1 dType:-1] subscribeNext:^(NSString *HTMLString) {
        [[self webView] loadHTMLString:HTMLString baseURL:[NSURL URLWithString:MDReactiveCocoaHTTPClientTestURLString]];
    }];
}

@end
