//
//  BeaconTableViewHelper.h
//  BeaconServiceDemoApp
//
//  Created by Marc Wandschneider on 05/08/2015.
//  Copyright (c) 2015 Google, Inc. All rights reserved.
//

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
