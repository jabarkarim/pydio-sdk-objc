//
//  PydioClient.m
//  PydioSDK
//
//  Created by ME on 09/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "PydioClient.h"
#import "AFHTTPRequestOperationManager.h"
#import "CookieManager.h"
#import "User.h"
#import "ListFilesRequest.h"
#import "AuthorizationClient.h"
#import "OperationsClient.h"
#import "PydioErrors.h"


static const int AUTHORIZATION_TRIES_COUNT = 1;

@interface PydioClient ()
@property(nonatomic,strong) AFHTTPRequestOperationManager* operationManager;
@property(nonatomic,strong) AuthorizationClient* authorizationClient;
@property(nonatomic,strong) OperationsClient* operationsClient;
@property(nonatomic,copy) void(^operationBlock)();
@property (nonatomic,copy) void(^successBlock)(id response);
@property(nonatomic,copy) void(^failureBlock)(NSError* error);
@property (nonatomic,copy) void(^successResponseBlock)(id responseObject);
@property (nonatomic,copy) void(^failureResponseBlock)(NSError *error);
@property(nonatomic,assign) int authorizationsTriesCount;

-(AFHTTPRequestOperationManager*)createOperationManager:(NSString*)server;
-(AuthorizationClient*)createAuthorizationClient;
-(OperationsClient*)createOperationsClient;
-(void)performAuthorizationAndOperation;
-(void)handleOperationFailure:(NSError*)error;
@end


@implementation PydioClient

-(NSURL*)serverURL {
    return self.operationManager.baseURL;
}

-(BOOL)progress {
    return self.authorizationClient.progress || self.operationsClient.progress;
}

#pragma mark - Initialization

-(instancetype)initWithServer:(NSString *)server {
    self = [super init];
    if (self) {
        self.operationManager = [self createOperationManager:server];
        self.authorizationClient = [self createAuthorizationClient];
        self.operationsClient = [self createOperationsClient];
    }
    
    return self;
}

-(void)setupResponseBlocks {
    [self setupSuccessResponseBlock];
    [self setupFailureResponseBlock];
}

-(void)setupSuccessResponseBlock {
    __weak typeof(self) weakSelf = self;
    self.successResponseBlock = ^(id response){
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.successBlock(response);
        [strongSelf clearBlocks];
    };
}

-(void)setupFailureResponseBlock {
    __weak typeof(self) weakSelf = self;
    self.failureResponseBlock = ^(NSError *error){
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf handleOperationFailure:error];
    };
}

-(void)setupCommons:(void(^)(id result))success failure:(void(^)(NSError *))failure {
    [self resetAuthorizationTriesCount];
    self.successBlock = success;
    self.failureBlock = failure;
    [self setupResponseBlocks];
}


#pragma mark -

-(BOOL)listWorkspacesWithSuccess:(void(^)(NSArray* workspaces))success failure:(void(^)(NSError* error))failure {
    if (self.progress) {
        return NO;
    }
    
    [self setupCommons:success failure:failure];
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf.operationsClient listWorkspacesWithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)listNodes:(ListFilesRequest *)request WithSuccess:(void(^)(NSArray* files))success failure:(void(^)(NSError* error))failure {
    if (self.progress) {
        return NO;
    }
    
    [self setupCommons:success failure:failure];
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf.operationsClient listFiles:[request dictionaryRepresentation] WithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();

    
    return YES;
}

#pragma mark -

-(void)clearBlocks {
    self.operationBlock = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
    self.successResponseBlock = nil;
    self.failureResponseBlock = nil;
}

-(AFHTTPRequestOperationManager*)createOperationManager:(NSString*)server {
    return [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:server]];
}

-(AuthorizationClient*)createAuthorizationClient {
    AuthorizationClient *client = [[AuthorizationClient alloc] init];
    client.operationManager = self.operationManager;
    
    return client;
}

-(OperationsClient*)createOperationsClient {
    OperationsClient *client = [[OperationsClient alloc] init];
    client.operationManager = self.operationManager;
    
    return client;
}

-(void)performAuthorizationAndOperation {
    self.authorizationsTriesCount--;
    [self.authorizationClient authorizeWithSuccess:^{
        self.operationBlock();
    } failure:^(NSError *error) {
        self.failureBlock(error);
        [self clearBlocks];
    }];
}

-(void)handleOperationFailure:(NSError*)error {
    if ([self isAuthorizationError:error] && self.authorizationsTriesCount > 0) {
        [self performAuthorizationAndOperation];
    } else {
        self.failureBlock(error);
        [self clearBlocks];
    }
}

-(BOOL)isAuthorizationError:(NSError *)error {
    return [error.domain isEqualToString:PydioErrorDomain] && error.code == PydioErrorUnableToLogin;
}

-(void)resetAuthorizationTriesCount {
    self.authorizationsTriesCount = AUTHORIZATION_TRIES_COUNT;
}

@end
