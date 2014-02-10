//
//  SKProduct+LocalizedPrice.m
//
//  Created by Soemarko Ridwan on 2/8/14.
//  Copyright (c) 2014 Soemarko Ridwan. All rights reserved.
//

#import "SKProduct+LocalizedPrice.h"

@implementation SKProduct (LocalizedPrice)

- (NSString *)localizedPrice {
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	[numberFormatter setLocale:self.priceLocale];

	return [numberFormatter stringFromNumber:self.price];
}

@end
