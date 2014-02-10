//
//  SRIapManager.m
//
//  Created by Soemarko Ridwan on 2/8/14.
//  Copyright (c) 2014 Soemarko Ridwan. All rights reserved.
//

#define user_defaults_set_bool(key, b)   { [[NSUserDefaults standardUserDefaults] setBool:b    forKey:key]; [[NSUserDefaults standardUserDefaults] synchronize]; }

#define kIAPProductIDs [NSSet setWithObject:@"com.company.app.removeads"]
#define kIAPVerifyURL [NSURL URLWithString:@"http://server.com/verifyProduct.php"]

#import "SRIapManager.h"
#import "SKProduct+LocalizedPrice.h"

@implementation SRIapManager

static SRIapManager *_sharedManager;

+ (SRIapManager *)shared {
	if (!_sharedManager) {
		static dispatch_once_t oncePredicate;
		dispatch_once(&oncePredicate, ^{
			_sharedManager = [[self alloc] init];
			[_sharedManager beginProductsRequest];
		});
	}

	return _sharedManager;
}

- (void)beginProductsRequest {
	productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:kIAPProductIDs];

	[productRequest setDelegate:self];
	[productRequest start];

	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	NSArray *products = response.products;

	if (products.count == 1) {
		removeAdProduct = [products firstObject];
	}

	if (removeAdProduct) {
		NSLog(@"Product title: %@" , removeAdProduct.localizedTitle);
		NSLog(@"Product description: %@" , removeAdProduct.localizedDescription);
		NSLog(@"Product price: %@" , removeAdProduct.localizedPrice);
		NSLog(@"Product id: %@" , removeAdProduct.productIdentifier);
	}

    for (NSString *invalidProductId in response.invalidProductIdentifiers) {
		NSLog(@"Invalid product id: %@" , invalidProductId);
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kIAPProductsFetchedNotification object:self userInfo:nil];
}

#pragma mark - Public methods

- (NSString *)removeAdTitle {
	if (removeAdProduct) {
		return [NSString stringWithFormat:@"%@ %@", removeAdProduct.localizedTitle, removeAdProduct.localizedPrice];
	}
	else {
		return @"Remove ads";
	}
}

- (BOOL)canMakePurchases {
	return [SKPaymentQueue canMakePayments];
}

- (void)purchaseRemoveAd {
	if (!removeAdProduct) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kIAPTransactionFailedNotification object:self userInfo:nil];
		return;
	}

	SKPayment *payment = [SKPayment paymentWithProduct:removeAdProduct];
	[[SKPaymentQueue defaultQueue] addPayment:payment];
}

// !YOU SHOULDN'T NEED ANY CHANGES BEYOND THIS POINT!

- (void)restorePurchases {
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - Purchase helpers

- (void)finishTransaction:(SKPaymentTransaction *)transaction wasSuccessful:(BOOL)successful {
	[[SKPaymentQueue defaultQueue] finishTransaction:transaction];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:transaction forKey:@"transaction"];
	if (successful) {
		NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
		if ([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
			NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
			NSString *receiptString = [receiptData base64EncodedStringWithOptions:kNilOptions];
			receiptString = [receiptString stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];

			NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:kIAPVerifyURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
			[req setHTTPMethod:@"POST"];
			[req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

			NSString *postData = [NSString stringWithFormat:@"receiptdata=%@", receiptString];

			[req setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];

			NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
			[conn start];
		}
	}
	else {
		user_defaults_set_bool(kIAPUserDefaultRemoveAdIsPurchased, NO);
		[[NSNotificationCenter defaultCenter] postNotificationName:kIAPTransactionFailedNotification object:self userInfo:userInfo];
	}
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
		if (![kIAPProductIDs containsObject:transaction.payment.productIdentifier]) {
			continue;
		}

		switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchased:
				[self finishTransaction:transaction wasSuccessful:YES];
				break;
			case SKPaymentTransactionStateFailed:
				if (transaction.error.code != SKErrorPaymentCancelled) {
					// error!
					[self finishTransaction:transaction wasSuccessful:NO];
				}
				else {
					// this is fine, the user just cancelled, so don’t notify
					[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
				}
				break;
			case SKPaymentTransactionStateRestored:
				[self finishTransaction:transaction wasSuccessful:YES];
				break;
			default:
				break;
		}
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
	if (error.code != SKErrorPaymentCancelled) {
		[[[UIAlertView alloc] initWithTitle:@"Restore failed" message:error.localizedFailureReason delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil] show];
	}
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:nil];
	NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
	responseString = [responseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	NSDictionary *errCodes = @{
							   @21000: @"The App Store could not read the receipt object you provided.",
							   @21002: @"The data in the receipt-data property was malformed.",
							   @21003: @"The receipt could not be authenticated.",
							   @21004: @"The shared secret you provided does not match the shared secret on file for your account.",
							   @21005: @"The receipt server is not currently available.",
							   @21006: @"This receipt is valid but the subscription has expired.",
							   @21007: @"This receipt is a sandbox receipt, but it was sent to the production service for verification.",
							   @21008: @"This receipt is a production receipt, but it was sent to the sandbox service for verification."
							   };

	NSString *statusCode = [json objectForKey:@"status"];
	if ([statusCode integerValue] == 0) {
		user_defaults_set_bool(kIAPUserDefaultRemoveAdIsPurchased, YES);
		[[NSNotificationCenter defaultCenter] postNotificationName:kIAPTransactionSucceededNotification object:self userInfo:nil];
	}
	else {
		user_defaults_set_bool(kIAPUserDefaultRemoveAdIsPurchased, NO);
		[[NSNotificationCenter defaultCenter] postNotificationName:kIAPTransactionFailedNotification object:self userInfo:nil];

		NSString *errMessage = @"Unknown error.";
		if ([errCodes objectForKey:statusCode] != nil) {
			errMessage = [errCodes objectForKey:statusCode];
		}
		[[[UIAlertView alloc] initWithTitle:@"Purchase Failed!" message:errMessage delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	user_defaults_set_bool(kIAPUserDefaultRemoveAdIsPurchased, NO);
	[[NSNotificationCenter defaultCenter] postNotificationName:kIAPTransactionFailedNotification object:self userInfo:nil];

	[[[UIAlertView alloc] initWithTitle:@"Validation failed" message:error.localizedDescription delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil] show];
}

@end
