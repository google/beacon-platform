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
 * CRITICAL: All OAuth access (bearer) tokens are generated from the Google SignIn classes. If you
 *           aren't using Google SignIn, get rid of this header and re-implement
 *           +(NSString *)oauthBearerToken; with how you get your OAuth 2.0 access token.
 */
#import <Google/SignIn.h>

/**
 * Beacon Status values. Inactive beacons are mutable, but do not serve data via the Serving API.
 * Decommissioning a beacon is permanent and never undoable, ever. That beacon ID will be forever
 * unusable afterwards.
 */
extern NSString *const kEddystoneStatusActive;
extern NSString *const kEddystoneStatusInactive;
extern NSString *const kEddystoneStatusDecommissioned;

/**
 * The expected beacon stability. Will it always be in one place? Moving around a bunch?
 */
extern NSString *const kEddystoneStabilityStable;
extern NSString *const kEddystoneStabilityPortable;
extern NSString *const kEddystoneStabilityMobile;
extern NSString *const kEddystoneStabilityRoving;

/**
 * Most of the methods in this class return an errorInfo dictionary. This controls the key 
 * information in them. Status is guaranteed to be there, the others are not.
 */
extern NSString *const kRequestErrorStatus;
extern NSString *const kRequestErrorMessage;
extern NSString *const kRequestErrorObject;

extern NSString *const kRequestErrorOther;
extern NSString *const kRequestErrorNotYours;
extern NSString *const kRequestErrorNotRegistered;
extern NSString *const kRequestErrorAlreadyRegistered;

// Many random registration errors are because the beaconID has problmes.
extern NSString *const kRequestErrorUnknownRegistrationError;
extern NSString *const kRequestErrorRegisterPermissionDenied;

/**
 *=----------------------------------------------------------------------------------------------=
 * BSDAdminAPI Interface
 *=----------------------------------------------------------------------------------------------=
 * Methods for the Proximity Beacon Management API. These APIs allow you to register, decommission
 * and otherwise attach namespaced+typed data to your beacons.
 */
@interface BSDAdminAPI : NSObject

+ (void)informationForSpecifiedBeaconIDs:(NSArray *)ids
                       completionHandler:(void (^)(NSDictionary *,
                                                   NSDictionary *))completionHandler;

+ (void)beaconInfoFromBeaconID:(NSString *)beaconID
             completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

+ (void)attachmentsForBeaconID:(NSString *)beaconID
             completionHandler:(void (^)(NSArray *, NSDictionary *))completionHandler;

+ (void)registerBeaconWithBeaconID:(NSString *)beaconID
                          latitude:(NSNumber *)latitude
                         longitude:(NSNumber *)longitude
                         stability:(NSString *)stability
                 completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

+ (void)registerBeaconWithBeaconID:(NSString *)beaconID
                           placeID:(NSString *)placeID
                         stability:(NSString *)stability
                 completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

+ (void)updateBeaconWithBeaconID:(NSString *)beaconID
                        latitude:(NSNumber *)latitude
                       longitude:(NSNumber *)longitude
                       stability:(NSString *)stability
               completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

+ (void)updateBeaconWithBeaconID:(NSString *)beaconID
                         placeID:(NSString *)placeID
                       stability:(NSString *)stability
               completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

+ (void)activateBeaconWithBeaconID:(NSString *)beaconID
                 completionHandler:(void (^)(NSDictionary *))completionHandler;

+ (void)deactivateBeaconWithBeaconID:(NSString *)beaconID
                   completionHandler:(void (^)(NSDictionary *))completionHandler;

+ (void)decommissionBeaconWithBeaconID:(NSString *)beaconID
                     completionHandler:(void (^)(NSDictionary *))completionHandler;

+ (void)listAvailableNamespaces:(void (^)(NSArray *, NSDictionary *))completionHandler;

+ (void)addAttachmentToBeaconID:(NSString *)beaconID
             withNamespacedType:(NSString *)namespacedType
                 attachmentData:(NSString *)data
              completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

+ (void)deleteAttachmentForBeaconID:(NSString *)beaconID
                              named:(NSString *)attachmentName
                  completionHandler:(void (^)(NSDictionary *))completionHandler;

+ (void)deleteAllAttachmentsForBeaconID:(NSString *)beaconID
                     withNamespacedType:(NSString *)namespacedType
                      completionHandler:(void (^)(int num_deleted,
                                                  NSDictionary *errorInfo))completionHandler;

@end
