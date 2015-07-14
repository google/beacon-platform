// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

/**
 *=----------------------------------------------------------------------------------------------=
 * BSDRESTRequest Interface
 *=----------------------------------------------------------------------------------------------=
 * Basically one method to issue JSON REST requests against a server. You're responsible for
 * setting all headers for things such as auth, etc.  The underlying mechanism is NSURLSession,
 * which supports HTTP and HTTPS.
 */
@interface BSDRESTRequest : NSObject

+ (void)RESTfulJSONRequestToURL:(NSURL *)url
                         method:(NSString *)method
                       postBody:(NSData *)postBody
                 requestHeaders:(NSDictionary *)requestHeaders
              completionHandler:(void (^)(NSInteger httpResponseCode, NSString *response,
                                          NSError *error))completionHandler;

/**
 * Some convenient utils that we need in a few places:
 */
+ (NSData *)hexStringToNSData:(NSString *)hexString;
+ (NSString *)sanitiseBeaconID:(NSString *)beaconID;  


@end
