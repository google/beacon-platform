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

#import "BSDServingAPI.h"

#import "BSDRESTRequest.h"

NSString *const kServingRequestErrorNoSuchBeacon = @"no_such_beacon";
NSString *const kServingRequestErrorUnknown = @"unknown_error";

NSString *const kServingRequestErrorStatus = @"error_status";
NSString *const kServingRequestErrorMessage = @"error_message";
NSString *const kServingRequestErrorObject = @"error_details_object";

@implementation BSDServingAPI

+ (void)infoForObservedBeaconID:(NSString *)beaconID
                         APIKey:(NSString *)apiKey
              completionHandler:(void (^)(NSArray *, NSDictionary *))completionHandler {

  NSData *binaryID = [BSDRESTRequest
      hexStringToNSData:[BSDRESTRequest sanitiseBeaconID:beaconID]];

  NSDictionary *observation = @{
      @"observations" : @[ @{
        @"advertisedId" : @{
          @"type" : @"EDDYSTONE",
          @"id" : [binaryID base64EncodedStringWithOptions:0],
        },
        @"telemetry" : @"",
        @"timestampMs" : [BSDServingAPI RFC3339Timestamp],
      } ],
      @"namespacedTypes" : @"com.google.location.locus/*",
 };

  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:observation
                                                     options:0
                                                       error:NULL];
  NSString *server =
      @"https://proximitybeacon.googleapis.com/v1beta1/beaconinfo:getforobserved?key=";
  server = [server stringByAppendingString:apiKey];

  NSDictionary *httpHeaders = @{
      @"Content-Type" : @"application/json",
      @"Accept" : @"application/json",
 };

  [BSDRESTRequest RESTfulJSONRequestToURL:[NSURL URLWithString:server]
                                   method:@"POST"
                                 postBody:jsonData
                           requestHeaders:httpHeaders
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *results = nil, *error = nil;
        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
              [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
        } else {
          error = [BSDServingAPI errorWithRequestError:requestError
                                          responseBody:response
                                         defaultStatus:kServingRequestErrorNoSuchBeacon];
        }

        completionHandler(results[@"beacons"], error);
      }
  ];
}

///
/// The server only wants UTC, so make sure not to add any timezone stuff here.
///
+ (NSString *)RFC3339Timestamp {
  NSDate *now = [[NSDate alloc] init];
  NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
  NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];

  [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
  [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];

  NSString *dateString = [rfc3339DateFormatter stringFromDate:now];

  return dateString;
}


+ (NSDictionary *)errorWithRequestError:(NSError *)requestError
                           responseBody:(NSString *)body
                          defaultStatus:(NSString *)defaultStatus {
  // If the error is from NSURLRequest itself, then just return that. Chances are: it's a timoeut.
  if (requestError) {
    return @{
        kServingRequestErrorStatus: @"request_error",
        kServingRequestErrorStatus: @"Something went wrong with the request to the remote server; "
                                    @"check the error object (in this dictionary) for details.",
        kServingRequestErrorObject: requestError
    };
  }

  NSDictionary *error = [NSJSONSerialization JSONObjectWithData:
      [body dataUsingEncoding:NSUTF8StringEncoding]
                                                        options:kNilOptions
                                                          error:NULL];

  NSDictionary *details = error[@"error"];
  if (details[@"message"]) {
    return @{
        kServingRequestErrorStatus : details[@"status"],
        kServingRequestErrorMessage : details[@"message"],
    };
  } else if (error[@"status"]) {
    return @{
        kServingRequestErrorStatus : @"unknown_error",
        kServingRequestErrorMessage : details[@"status"],
    };
  } else {
    return @{
        kServingRequestErrorStatus : @"unknown_error",
        kServingRequestErrorMessage : defaultStatus,
    };
  }
}

@end
