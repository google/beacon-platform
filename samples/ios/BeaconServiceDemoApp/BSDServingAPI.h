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
 * CRITICAL: While this API does not *authenticate* using OAuth or any such thing, you must still
 *           pass an API key to calls made against it.
 */

/**
 * Most of the methods in this class return an errorInfo dictionary. This controls the key
 * information in them. Status is guaranteed to be there, the others are not.
 */
extern NSString *const kServingRequestErrorStatus;
extern NSString *const kServingRequestErrorMessage;
extern NSString *const kServingRequestErrorObject;

extern NSString *const kServingRequestErrorNoSuchBeacon;
extern NSString *const kServingRequestErrorUnknown;

/**
 *=----------------------------------------------------------------------------------------------=
 * BSDServingAPI Interface
 *=----------------------------------------------------------------------------------------------=
 */
@interface BSDServingAPI : NSObject

/**
 * When a beacon is sighted in the wild, call this function to report that sighting. You can also
 * provide a namespaced type indicating that you'd like to learn about any attachments associated
 * with this beacon (provided you have access to them). You may provide nil to indicate you don't
 * care about the attachment data or "*" to indicate you want any attachment data for which you
 * have access.
 */
- (void)infoForObservedBeaconID:(NSString *)beaconID
                         APIKey:(NSString *)apiKey
              completionHandler:(void (^)(NSArray *, NSDictionary *))completionHandler;

@end
