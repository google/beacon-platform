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

#import "BSDDiagnosticsAPI.h"

#import "BSDRESTRequest.h"

static NSString *const kServerPath = @"https://proximitybeacon.googleapis.com/v1beta1";

NSString *const kDiagnosticsRequestErrorStatus = @"error_status";
NSString *const kDiagnosticsRequestErrorMessage = @"error_message";

static NSString *const kDiagnosticsUnknownError = @"unknown_diagnostics_error";

@implementation BSDDiagnosticsAPI

+ (void)diagnosticsInfoForBeaconID:(NSString *)beaconID
                 resultingPageSize:(NSNumber *)pageSize
                         pageToken:(NSString *)pageToken
                       alertFilter:(NSString *)alertFilter
                 completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {

  NSString *beaconIDStr;

  // For this API, a beacon name of "-" means fetch for all beacons I own.
  if (beaconID) {
    beaconIDStr = [NSString stringWithFormat:@"beacons/3!%@",
        [BSDRESTRequest sanitiseBeaconID:beaconID]];
  } else {
    beaconIDStr = @"beacons/-";
  }

  NSString *bearer = [@"Bearer " stringByAppendingString:[BSDDiagnosticsAPI oauthBearerToken]];
  NSString *server = [BSDDiagnosticsAPI
      serverURLForQueryPath:[NSString stringWithFormat:@"/%@/diagnostics", beaconIDStr]];

  // Attach the possible query params if there are any.
  NSMutableDictionary *queryParams = [NSMutableDictionary dictionary];
  if (pageSize) {
    queryParams[@"pageSize"] = pageSize;
  }
  if (pageToken) {
    queryParams[@"pageToken"] = pageToken;
  }
  if (alertFilter) {
    queryParams[@"alertFilter"] = alertFilter;
  }

  NSMutableString *queryString = [NSMutableString stringWithString:@""];
  for (NSString *key in queryParams) {
    if ([queryString length] > 0) {
      [queryString appendString:@"&"];
    }
    [queryString appendString:[NSString stringWithFormat:@"%@=%@", key, queryParams[key]]];
  }

  if ([queryString length] > 0) {
    server = [server stringByAppendingString:[NSString stringWithFormat:@"?%@", queryString]];
  }

  NSURL *url = [NSURL URLWithString:server];

  NSDictionary *httpHeaders = @{
      @"Authorization" : bearer,
      @"Accept" : @"application/json",
  };

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"GET"
                                 postBody:nil
                           requestHeaders:httpHeaders
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSLog(@"%d", (int)httpResponseCode);
        NSLog(@"%@", response);
        NSDictionary *results = nil, *error = nil;
        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
                     [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
        } else {
          error = [BSDDiagnosticsAPI errorWithResponseBody:response];
        }
         
        completionHandler(results, error);
      }
  ];

}

+ (NSString *)oauthBearerToken {
  return [GIDSignIn sharedInstance].currentUser.authentication.accessToken;
}

+ (NSString *)serverURLForQueryPath:(NSString *)queryPath {
  return [kServerPath stringByAppendingString: queryPath];
}

+ (NSDictionary *)errorWithResponseBody:(NSString *)body {
  NSDictionary *error = [NSJSONSerialization JSONObjectWithData:
      [body dataUsingEncoding:NSUTF8StringEncoding]
                                                        options:kNilOptions
                                                          error:NULL];

  NSDictionary *details = error[@"error"];
  if (details[@"message"]) {
    return @{
        kDiagnosticsRequestErrorStatus : details[@"status"],
        kDiagnosticsRequestErrorMessage : details[@"message"],
    };
  } else if (error[@"status"]) {
    return @{
        kDiagnosticsRequestErrorStatus : @"unknown_error",
        kDiagnosticsRequestErrorMessage : details[@"status"],
    };
  } else {
    return @{
        kDiagnosticsRequestErrorStatus : @"unknown_error",
        kDiagnosticsRequestErrorMessage : kDiagnosticsUnknownError,
    };
  }
}

@end
