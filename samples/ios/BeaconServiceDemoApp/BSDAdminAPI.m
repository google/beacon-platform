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

#import "BSDAdminAPI.h"

#import "BSDRESTRequest.h"

static NSString *const kServerPath = @"https://proximitybeacon.googleapis.com/v1beta1";

NSString *const kEddystoneStatusActive = @"ACTIVE";
NSString *const kEddystoneStatusInactive = @"INACTIVE";
NSString *const kEddystoneStatusDecommissioned = @"DECOMMISSIONED";

NSString *const kEddystoneStabilityStable = @"STABLE";
NSString *const kEddystoneStabilityPortable = @"PORTABLE";
NSString *const kEddystoneStabilityMobile = @"MOBILE";
NSString *const kEddystoneStabilityRoving = @"ROVING";

NSString *const kRequestErrorStatus = @"error_status";
NSString *const kRequestErrorMessage = @"error_message";

NSString *const kRequestErrorOther = @"other_error_see_requestError_object";
NSString *const kRequestErrorUnknown = @"unknown_error";
NSString *const kRequestErrorNotYours = @"not_your_beacon";
NSString *const kRequestErrorNotRegistered = @"not_registered";
NSString *const kRequestErrorAlreadyRegistered = @"beacon_already_registered";
NSString *const kRequestErrorUnknownRegistrationError =
    @"unknown_registration_error_check_for_invalid_beaconid";
NSString *const kRequestErrorRegisterPermissionDenied = @"you_cannot_register_this_beacon";
NSString *const kRequestErrorModifyAttachmentNotYours = @"not_your_beacon_or_namespace";

@implementation BSDAdminAPI

+ (void)informationForSpecifiedBeaconIDs:(NSArray *)beaconIDs
                       completionHandler:(void (^)(NSDictionary *,
                                                   NSDictionary *))completionHandler {

  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];

  __block int callbacks_called = 0;
  __block BOOL completionHandlerCalled = NO;

  for (NSString *beaconID in beaconIDs) {
    // Add a task to the group
    [BSDAdminAPI beaconInfoFromBeaconID:beaconID completionHandler:
        ^(NSDictionary *beaconInfo, NSDictionary *errorInfo) {
          @synchronized(self) {
            callbacks_called++;

            if (beaconInfo || errorInfo) {
              @synchronized(results) {
                if (beaconInfo) {
                  [results setObject:beaconInfo forKey:beaconID];
                } else {
                  [results setObject:errorInfo forKey:beaconID];
                }
              }
            }
          }

          NSLog(@"%d %d %d %d", (int)completionHandlerCalled,
                callbacks_called,
                (int)[results count],
                (int)[beaconIDs count]);

          @synchronized (self) {
            // If we've fetched them all or we've waited too long, then call the completion handler.
            if (!completionHandlerCalled
                && (callbacks_called == [beaconIDs count]
                    || [NSDate timeIntervalSinceReferenceDate] > startTime + 10)) {
                  completionHandler(results, nil);
                  completionHandlerCalled = YES;
                }
          }
        }
    ];
  }
}

+ (void)addAttachmentToBeaconID:(NSString *)beaconID
             withNamespacedType:(NSString *)namespacedType
                 attachmentData:(NSString *)stringData
              completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  NSData *base64data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *attachmentData = @{
      @"namespacedType" : namespacedType,
      @"data" : [base64data base64EncodedStringWithOptions:0]
  };

  // Convert this to a JSON string.
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:attachmentData
                                                     options:(NSJSONWritingOptions)0
                                                       error:nil];

  NSString *beaconIDStr = [NSString stringWithFormat:@"beacons/3!%@",
                           [BSDRESTRequest sanitiseBeaconID:beaconID]];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:[BSDAdminAPI oauthBearerToken]];
  NSString *server = [BSDAdminAPI
      serverURLForQueryPath:[NSString stringWithFormat:@"/%@/attachments", beaconIDStr]];
  NSURL *url = [NSURL URLWithString:server];

  NSDictionary *httpHeaders = @{
      @"Authorization" : bearerHeader,
      @"Content-Type" : @"application/json",
      @"Accept" : @"application/json",
  };

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"POST"
                                 postBody:jsonData
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
            error = [BSDAdminAPI errorWithResponseBody:response
                                         defaultStatus:kRequestErrorModifyAttachmentNotYours];
        }

        completionHandler(results, error);
      }
  ];
}

+ (void)deleteAttachmentForBeaconID:(NSString *)beaconID
                              named:(NSString *)attachmentName
                  completionHandler:(void (^)(NSDictionary *))completionHandler {

  // Get the Authorization header and server URL ready.
  NSString *bearer = [BSDAdminAPI oauthBearerToken];

  NSString *queryPath = [NSString stringWithFormat:@"/%@", attachmentName];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:bearer];
  NSString *server = [BSDAdminAPI serverURLForQueryPath:queryPath];
  NSURL *url = [NSURL URLWithString:server];

  NSDictionary *httpHeaders = @{
      @"Authorization" : bearerHeader,
      @"Content-Type" : @"application/json",
      @"Accepts" : @"application/json"
  };

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"DELETE"
                                 postBody:nil
                           requestHeaders:httpHeaders
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSLog(@"%d", (int)httpResponseCode);
        NSLog(@"%@", response);
        NSDictionary *error = nil;

        if (httpResponseCode != 200) {
            error = [BSDAdminAPI errorWithResponseBody:response
                                         defaultStatus:kRequestErrorModifyAttachmentNotYours];
        }
        
        completionHandler(error);
      }
  ];
}

+ (void)deleteAllAttachmentsForBeaconID:(NSString *)beaconID
                     withNamespacedType:(NSString *)namespacedType
                      completionHandler:(void (^)(int, NSDictionary *))completionHandler {
  NSString *beaconIDStr = [NSString stringWithFormat:@"beacons/3!%@",
                           [BSDRESTRequest sanitiseBeaconID:beaconID]];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:[BSDAdminAPI oauthBearerToken]];
  NSString *server = [BSDAdminAPI
      serverURLForQueryPath:[NSString stringWithFormat:@"/%@/attachments:batchDelete",
                                                       beaconIDStr]];
  NSURL *url = [NSURL URLWithString:server];

  NSDictionary *httpHeaders = @{
      @"Authorization" : bearerHeader,
      @"Content-Type" : @"application/json",
      @"Accept" : @"application/json",
  };

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"POST"
                                 postBody:nil
                           requestHeaders:httpHeaders
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSLog(@"%d", (int)httpResponseCode);
        NSLog(@"%@", response);
        NSDictionary *error = nil, *results;
        int num_deleted = -1;

        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
              [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
          if (results) {
            num_deleted = [results[@"numDeleted"] intValue];
          }
        } else {
          error = [BSDAdminAPI errorWithResponseBody:response
                                       defaultStatus:kRequestErrorModifyAttachmentNotYours];
        }

        completionHandler(num_deleted, error);
      }
   ];
}

+ (void)beaconInfoFromBeaconID:(NSString *)beaconID
             completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  NSString *bearer = [BSDAdminAPI oauthBearerToken];

  NSString *bearerHeader = [@"Bearer " stringByAppendingString:bearer];
  NSString *server = [BSDAdminAPI serverURLForQueryPath:[@"/beacons/3!"
      stringByAppendingString:[BSDRESTRequest sanitiseBeaconID:beaconID]]];

  NSURL *url = [NSURL URLWithString:server];

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"GET"
                                 postBody:nil
                           requestHeaders:@{ @"Authorization" : bearerHeader,
                                             @"Accept" : @"application/json" }
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *results = nil, *error = nil;
        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
              [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
        } else {
          error = [BSDAdminAPI errorWithResponseBody:response defaultStatus:kRequestErrorUnknown];
        }

        completionHandler(results, error);
      }
  ];
}

+ (void)attachmentsForBeaconID:(NSString *)beaconID
             completionHandler:(void (^)(NSArray *, NSDictionary *))completionHandler {
  NSString *bearer = [BSDAdminAPI oauthBearerToken];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:bearer];

  NSString *server = [BSDAdminAPI serverURLForQueryPath:[@"/beacons/3!"
      stringByAppendingString:[BSDRESTRequest sanitiseBeaconID:beaconID]]];
  server = [server stringByAppendingString:@"/attachments?namespacedType=*/*"];
  NSURL *url = [NSURL URLWithString:server];

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"GET"
                                 postBody:nil
                           requestHeaders:@{ @"Authorization" : bearerHeader }
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *results = nil, *error = nil;
        NSArray *attachments = nil;

        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
              [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
          if (results[@"attachments"]) {
            attachments = results[@"attachments"];
          } else {
            attachments = @[];
          }
        } else {
          error = [BSDAdminAPI errorWithResponseBody:response
                                       defaultStatus:kRequestErrorNotRegistered];
        }

        completionHandler(attachments, error);
      }
  ];
}

+ (void)registerBeaconWithBeaconID:(NSString *)beaconID
                          latitude:(NSNumber *)latitude
                         longitude:(NSNumber *)longitude
                         stability:(NSString *)stability
                 completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  [BSDAdminAPI modifyBeaconWithBeaconID:beaconID
                                placeID:nil
                                  latitude:latitude
                                 longitude:longitude
                                 stability:stability
                                  isUpdate:NO
                         completionHandler:completionHandler];
}

+ (void)registerBeaconWithBeaconID:(NSString *)beaconID
                           placeID:(NSString *)placeID
                         stability:(NSString *)stability
                 completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  [BSDAdminAPI modifyBeaconWithBeaconID:beaconID
                                placeID:placeID
                               latitude:nil
                              longitude:nil
                              stability:stability
                               isUpdate:NO
                      completionHandler:completionHandler];
}

+ (void)updateBeaconWithBeaconID:(NSString *)beaconID
                        latitude:(NSNumber *)latitude
                       longitude:(NSNumber *)longitude
                       stability:(NSString *)stability
               completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  [BSDAdminAPI modifyBeaconWithBeaconID:beaconID
                                placeID:nil
                               latitude:latitude
                              longitude:longitude
                              stability:stability
                               isUpdate:YES
                      completionHandler:completionHandler];
}

+ (void)updateBeaconWithBeaconID:(NSString *)beaconID
                         placeID:(NSString *)placeID
                       stability:(NSString *)stability
               completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  [BSDAdminAPI modifyBeaconWithBeaconID:beaconID
                                placeID:placeID
                               latitude:nil
                              longitude:nil
                              stability:stability
                               isUpdate:YES
                      completionHandler:completionHandler];
}

+ (void)modifyBeaconWithBeaconID:(NSString *)beaconID
                         placeID:(NSString *)placeID
                        latitude:(NSNumber *)latitude
                       longitude:(NSNumber *)longitude
                       stability:(NSString *)stability
                        isUpdate:(BOOL)isUpdate
               completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler {
  NSString *bearer = [BSDAdminAPI oauthBearerToken];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:bearer];

  NSString *server;
  if (isUpdate) {
    server = [BSDAdminAPI serverURLForQueryPath:
        [NSString stringWithFormat:@"/beacons/3!%@", [BSDRESTRequest sanitiseBeaconID:beaconID]]];
  } else {
    server = [BSDAdminAPI serverURLForQueryPath:@"/beacons:register"];
  }
  NSURL *url = [NSURL URLWithString:server];

  NSDictionary *beaconObj = [BSDAdminAPI generateBeaconObjectForEddystoneBeaconID:beaconID
                                                                          placeID:placeID
                                                                         latitude:latitude
                                                                        longitude:longitude
                                                                        stability:stability
                                                                         isUpdate:isUpdate];

  // JSON-ify that puppy and get an NSData for it.
  NSData *jsonBody = [NSJSONSerialization dataWithJSONObject:beaconObj
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:nil];

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:isUpdate ? @"PUT" : @"POST"
                                 postBody:jsonBody
                           requestHeaders:@{ @"Authorization" : bearerHeader,
                                             @"Content-Type" : @"application/json",
                                             @"Accept" : @"application/json" }
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *results = nil, *error = nil;
        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
              [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
        } else {
          error = [BSDAdminAPI errorWithResponseBody:response
                                       defaultStatus:kRequestErrorUnknown];
        }

        completionHandler(results, error);
      }
  ];
}

+ (void)activateBeaconWithBeaconID:(NSString *)beaconID
                 completionHandler:(void (^)(NSDictionary *))completionHandler {
  [BSDAdminAPI updateStatusForBeaconWithBeaconID:beaconID
                                               verb:@"activate"
                                  completionHandler:completionHandler];
}

+ (void)deactivateBeaconWithBeaconID:(NSString *)beaconID
                   completionHandler:(void (^)(NSDictionary *))completionHandler {
  [BSDAdminAPI updateStatusForBeaconWithBeaconID:beaconID
                                               verb:@"deactivate"
                                  completionHandler:completionHandler];
}
+ (void)decommissionBeaconWithBeaconID:(NSString *)beaconID
                     completionHandler:(void (^)(NSDictionary *))completionHandler {
  [BSDAdminAPI updateStatusForBeaconWithBeaconID:beaconID
                                               verb:@"decommission"
                                  completionHandler:completionHandler];
}

+ (void)updateStatusForBeaconWithBeaconID:(NSString *)beaconID
                                     verb:(NSString *)verb
                        completionHandler:(void (^)(NSDictionary *))completionHandler {
  NSString *bearer = [BSDAdminAPI oauthBearerToken];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:bearer];

  NSString *server = [BSDAdminAPI serverURLForQueryPath:[@"/beacons/3!"
      stringByAppendingString:[BSDRESTRequest sanitiseBeaconID:beaconID]]];
  server = [server stringByAppendingString:[@":" stringByAppendingString:verb]];
  NSURL *url = [NSURL URLWithString:server];

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"POST"
                                 postBody:nil
                           requestHeaders:@{ @"Authorization" : bearerHeader }
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *error = nil;
        if (httpResponseCode != 200) {
          error = [BSDAdminAPI errorWithResponseBody:response
                                       defaultStatus:kRequestErrorNotRegistered];
        }

        completionHandler(error);
      }
  ];
}

+ (void)listAvailableNamespaces:(void (^)(NSArray *, NSDictionary *))completionHandler {
  NSString *bearer = [BSDAdminAPI oauthBearerToken];
  NSString *bearerHeader = [@"Bearer " stringByAppendingString:bearer];

  NSString *server = [BSDAdminAPI serverURLForQueryPath:@"/namespaces"];
  NSURL *url = [NSURL URLWithString:server];

  [BSDRESTRequest RESTfulJSONRequestToURL:url
                                   method:@"GET"
                                 postBody:nil
                           requestHeaders:@{ @"Authorization" : bearerHeader }
                        completionHandler:
      ^(NSInteger httpResponseCode, NSString *response, NSError *requestError) {
        NSDictionary *results, *error = nil;
        if (httpResponseCode == 200) {
          results = [NSJSONSerialization JSONObjectWithData:
                     [response dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];
        } else {
          error = [BSDAdminAPI errorWithResponseBody:response
                                       defaultStatus:kRequestErrorNotRegistered];
        }

        completionHandler(results[@"namespaces"], error);
      }
  ];
}

+ (NSDictionary *)generateBeaconObjectForEddystoneBeaconID:(NSString *)beaconID
                                                   placeID:(NSString *)placeID
                                                  latitude:(NSNumber *)latitude
                                                 longitude:(NSNumber *)longitude
                                                 stability:(NSString *)stability
                                                  isUpdate:(BOOL)isUpdate {
  // Need to convert the beaconID to binary. First, make sure no spaces.
  NSData *binaryID = [BSDRESTRequest hexStringToNSData: [BSDRESTRequest sanitiseBeaconID:beaconID]];

  NSDictionary *advertisedId = @{
      @"type" : @"EDDYSTONE",
      @"id" : [binaryID base64EncodedStringWithOptions:0]
  };

  NSString *beaconName = nil;
  if (isUpdate) {
    beaconName = [NSString stringWithFormat:@"beacons/3!%@", beaconID];
  }

  NSMutableDictionary *beaconInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
      advertisedId, @"advertisedId",
      @"ACTIVE", @"status",
      nil];

  if (placeID) {
    beaconInfo[@"placeId"] = placeID;
  } else {
    if (latitude && longitude) {
      beaconInfo[@"latLng"] = @{
          @"latitude" : latitude,
          @"longitude" : longitude
      };
    }
  }

  if ([stability length] > 0) {
    beaconInfo[@"expectedStability"] = stability;
  }

  if (beaconName) {
    beaconInfo[@"beaconName"] = beaconName;
  }

  return beaconInfo;
}

+ (NSString *)serverURLForQueryPath:(NSString *)queryPath {
  return [kServerPath stringByAppendingString: queryPath];
}

+ (NSDictionary *)errorWithResponseBody:(NSString *)body defaultStatus:(NSString *)defaultStatus {
  NSDictionary *error = [NSJSONSerialization JSONObjectWithData:
      [body dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:NULL];

  NSDictionary *details = error[@"error"];
  if (details[@"message"]) {
    return @{
        kRequestErrorStatus : details[@"status"],
        kRequestErrorMessage : details[@"message"],
    };
  } else if (error[@"status"]) {
    return @{
        kRequestErrorStatus : @"unknown_error",
        kRequestErrorMessage : details[@"status"],
    };
  } else {
    return @{
        kRequestErrorStatus : @"unknown_error",
        kRequestErrorMessage : defaultStatus,
    };
  }
}

+ (NSString *)oauthBearerToken {
  return [GIDSignIn sharedInstance].currentUser.authentication.accessToken;
}

@end
