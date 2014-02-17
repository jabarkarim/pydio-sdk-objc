//
//  OperationsClient.m
//  PydioSDK
//
//  Created by ME on 14/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "OperationsClient.h"
#import "AFHTTPRequestOperationManager.h"
#import "CookieManager.h"
#import "XMLResponseSerializer.h"
#import "XMLResponseSerializerDelegate.h"
#import "FailingResponseSerializer.h"
#import "NotAuthorizedResponse.h"
#import "PydioErrorResponse.h"
#import "PydioErrors.h"


extern NSString * const PydioErrorDomain;

@interface OperationsClient ()
@property (readwrite,nonatomic,assign) BOOL progress;

-(NSString*)actionWithTokenIfNeeded:(NSString*)action;
-(NSString*)urlStringForGetRegisters;
-(NSString*)urlStringForListFiles;
@end

@implementation OperationsClient
-(BOOL)listWorkspacesWithSuccess:(void(^)(NSArray *workspaces))success failure:(void(^)(NSError *error))failure {
    if (self.progress) {
        return NO;
    }
    self.progress = YES;
    
    NSString *listRegisters = [self urlStringForGetRegisters];
    self.operationManager.requestSerializer = [self defaultRequestSerializer];
    self.operationManager.responseSerializer = [self responseSerializerForGetRegisters];
    
    [self.operationManager GET:listRegisters parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.progress = NO;
        NSError *error = [self identifyError:responseObject];
        if (error) {
            failure(error);
        } else {
            success(responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        self.progress = NO;
        failure(error);
    }];
    
    
    return YES;
}

-(BOOL)listFiles:(NSDictionary*)params WithSuccess:(void(^)(NSArray* files))success failure:(void(^)(NSError* error))failure {
    if (self.progress) {
        return NO;
    }
    self.progress = YES;
    
    NSString *listFilesURL = [self urlStringForListFiles];
    self.operationManager.requestSerializer = [self defaultRequestSerializer];
    self.operationManager.responseSerializer = [self responseSerializerForListFiles];

    [self.operationManager GET:listFilesURL parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.progress = NO;
        NSError *error = [self identifyError:responseObject];
        if (error) {
            failure(error);
        } else {
            success(responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        self.progress = NO;
        failure(error);
    }];

    
    return YES;
}

#pragma mark -

-(NSString*)actionWithTokenIfNeeded:(NSString*)action {
    NSString *secureToken = [[CookieManager sharedManager] secureTokenForServer:self.operationManager.baseURL];
    
    NSString *result = [NSString stringWithFormat:@"index.php?get_action=%@",action];
    if (secureToken) {
        result = [result stringByAppendingFormat:@"&secure_token=%@",secureToken];
    }
    
    return result;
}

-(NSString*)urlStringForGetRegisters {
    return [[self actionWithTokenIfNeeded:@"get_xml_registry"] stringByAppendingString:@"&xPath=user/repositories"];
}

-(NSString*)urlStringForListFiles {
    return [self actionWithTokenIfNeeded:@"ls"];
}

-(AFHTTPRequestSerializer*)defaultRequestSerializer {
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    [serializer setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
    [serializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [serializer setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [serializer setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [serializer setValue:@"true" forHTTPHeaderField:@"Ajxp-Force-Login"];
    [serializer setValue:@"ajaxplorer-ios-client/1.0" forHTTPHeaderField:@"User-Agent"];
    
    return serializer;
}

-(AFHTTPResponseSerializer*)responseSerializerForGetRegisters {
    NSArray *serializers = [self defaultResponseSerializersWithSerializer:[self createSerializerForRepositories]];
    
    return [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

-(AFHTTPResponseSerializer*)responseSerializerForListFiles {
    NSArray *serializers = [self defaultResponseSerializersWithSerializer:[self createSerializerForListFiles]];
    
    return [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

-(NSArray*)defaultResponseSerializersWithSerializer:(XMLResponseSerializer*)serializer {
    return @[
             [self createSerializerForNotAuthorized],
             [self createSerializerForErrorResponse],
             serializer,
             [self createFailingSerializer]
            ];
}

-(XMLResponseSerializer*)createSerializerForNotAuthorized {
    NotAuthorizedResponseSerializerDelegate *delegate = [[NotAuthorizedResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForErrorResponse {
    ErrorResponseSerializerDelegate *delegate = [[ErrorResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForRepositories {
    WorkspacesResponseSerializerDelegate *delegate = [[WorkspacesResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForListFiles {
    ListFilesResponseSerializerDelegate *delegate = [[ListFilesResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(FailingResponseSerializer*)createFailingSerializer {
    return [[FailingResponseSerializer alloc] init];
}

-(NSError *)identifyError:(id)potentialError {
    NSError *error = nil;
    if ([potentialError isKindOfClass:[NotAuthorizedResponse class]]) {
        error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorUnableToLogin userInfo:nil];
    } else if ([potentialError isKindOfClass:[PydioErrorResponse class]]) {
        error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorErrorResponse userInfo:
                 @{NSLocalizedFailureReasonErrorKey: [potentialError message]}];
    }
    
    return error;
}

@end
