//
//  SKProduct+LocalizedPrice.h
//
//  Created by Soemarko Ridwan on 2/8/14.
//  Copyright (c) 2014 Soemarko Ridwan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface SKProduct (LocalizedPrice)

@property (nonatomic, readonly) NSString *localizedPrice;

@end
