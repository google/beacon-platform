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
 * Most of the methods in this class return an errorInfo dictionary. This controls the key
 * information in them. Status is guaranteed to be there, the others are not.
 */
extern NSString *const kDiagnosticsRequestErrorStatus;
extern NSString *const kDiagnosticsRequestErrorMessage;
extern NSString *const kDiagnosticsRequestErrorObject;

/**
 *=----------------------------------------------------------------------------------------------=
 * BSDDiagnosticsAPI Interface
 *=----------------------------------------------------------------------------------------------=
 */
@interface BSDDiagnosticsAPI : NSObject

+ (void)diagnosticsInfoForBeaconID:(NSString *)beaconID
                 resultingPageSize:(NSNumber *)pageSize
                         pageToken:(NSString *)pageToken
                       alertFilter:(NSString *)alertFilter
                 completionHandler:(void (^)(NSDictionary *, NSDictionary *))completionHandler;

@end
