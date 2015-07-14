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

@implementation BSDServingAPI

- (void)infoForObservedBeaconID:(NSString *)beaconID
                         APIKey:(NSString *)apiKey
              completionHandler:(void (^)(NSArray *, NSDictionary *))completionHandler {

  NSData *binaryID = [BSDRESTRequest hexStringToNSData:[BSDRESTRequest sanitiseBeaconID:beaconID]];

  NSDictionary *observation = @{
      @"observations" : @[ @{
        @"advertisedId" : @{
          @"type" : @(1),
          @"id" : [binaryID base64EncodedStringWithOptions:0],
        },
        @"timestampMs" : [BSDServingAPI RFC3339Timestamp],
      } ],
      @"namespacedTypes" : @"*",
  };

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:observation
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  NSString *server =
      @"https://proximitybeacon.googleapis.com/v1beta1/beaconinfo:getforobserved?key=";
  server = [server stringByAppendingString:apiKey];

  [BSDRESTRequest RESTfulJSONRequestToURL:[NSURL URLWithString:server]
                                   method:@"POST"
                                 postBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                           requestHeaders:@{}
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *results = nil, *error = nil;
        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
              [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
        } else {
          error = [BSDServingAPI errorWithResponseBody:response
                                         defaultStatus:kServingRequestErrorNoSuchBeacon];
        }
        
        completionHandler(results[@"beacons"], error);
      }
  ];
}

+ (NSString *)RFC3339Timestamp {
  NSDate *now = [[NSDate alloc] init];
  NSTimeZone *localTimeZone = [NSTimeZone systemTimeZone];
  NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
  NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];

  [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
  [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"];
  [rfc3339DateFormatter setTimeZone:localTimeZone];

  NSString *dateString = [rfc3339DateFormatter stringFromDate:now];

  return dateString;
}

+ (NSDictionary *)errorWithResponseBody:(NSString *)body defaultStatus:(NSString *)defaultStatus {
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
