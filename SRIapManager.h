//
//  SRIapManager.h
//
//  Created by Soemarko Ridwan on 2/8/14.
//  Copyright (c) 2014 Soemarko Ridwan. All rights reserved.
//

#import <StoreKit/StoreKit.h>

#define kIAPProductsFetchedNotification @"kInAppPurchaseManagerProductsFetchedNotification"
#define kIAPTransactionFailedNotification @"kInAppPurchaseManagerTransactionFailedNotification"
#define kIAPTransactionSucceededNotification @"kInAppPurchaseManagerTransactionSucceededNotification"

#define kIAPUserDefaultRemoveAdIsPurchased @"kIAPUserDefaultRemoveAdTransactionReceipt"

@interface SRIapManager : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver, NSURLConnectionDataDelegate> {
	SKProduct *removeAdProduct;
	SKProductsRequest *productRequest;
	NSMutableData *responseData;
}

+ (SRIapManager *)shared;

- (NSString *)removeAdTitle;
- (BOOL)canMakePurchases;
- (void)purchaseRemoveAd;
- (void)restorePurchases;

@end
