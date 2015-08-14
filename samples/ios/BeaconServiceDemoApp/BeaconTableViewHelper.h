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

#import <UIKit/UIKit.h>

@interface BeaconTableViewHelper : NSObject

/**
 * This is a dictionary keyed by beaconIDs (hex string form, spaceds every four bytes) where the
 * values are BeaconInfo objects (dictionaries here) as returned by the Proximity Beacon API.
 */
@property(nonatomic) NSDictionary *beaconRegistrationData;

/**
 * This is an array of hex beaconID strings (space every 4 bytes).
 */
@property(nonatomic) NSArray *scannedBeaconList;

- (instancetype)initWithTableView:(UITableView *)tableView
                   viewController:(UIViewController *)viewController
         moreButtonCellIdentifier:(NSString *)moreButtonCellIdentifier;

/**
 * Since we're doign segues on behalf of view controllers, we'll need to get their notification
 * for the pending segue as well. This isn't the cleanest of designs, but, it'll do for now.
 */
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender;

- (void)setShouldShowMoreButton:(BOOL)shouldShowMoreButton;

@end
