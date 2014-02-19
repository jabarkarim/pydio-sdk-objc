//
//  BlocksCallResult.h
//  PydioSDK
//
//  Created by ME on 19/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>


@class AFHTTPRequestOperation;

typedef void (^SuccessBlock)(id responseObject);
typedef void (^FailureBlock)(NSError *error);

@interface BlocksCallResult : NSObject
@property(nonatomic,assign) BOOL successBlockCalled;
@property(nonatomic,assign) BOOL failureBlockCalled;
@property(nonatomic,strong) id receivedResponse;
@property(nonatomic,strong) NSError *receivedError;

+(instancetype)result;
+(instancetype)successWithResponse:(id)response;
+(instancetype)failureWithError:(NSError*)error;

-(SuccessBlock)successBlock;
-(FailureBlock)failureBlock;
@end