//
//  PydioClient.h
//  PydioSDK
//
//  Created by ME on 09/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PydioClient : NSObject
@property (readonly,nonatomic,strong) NSURL* serverURL;
@property (readonly,nonatomic,assign) BOOL progress;

-(instancetype)initWithServer:(NSString *)server;

-(BOOL)listFiles;
@end
