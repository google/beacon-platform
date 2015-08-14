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

#import "BeaconTableViewHelper.h"

#import "BSDAdminAPI.h"
#import "ESSEddystone.h"
#import "RegisterBeaconViewController.h"

static NSString *const kCellIdentifier = @"table_view_cell";
static NSString *const kShowRegisterBeaconSegueName = @"ShowRegisterBeaconSegue";

@interface BeaconTableViewHelper ()
    <RegisterBeaconViewControllerDelegate, UITableViewDataSource, UITableViewDelegate> {
  UITableView *_tableView;

  NSArray *_recentlyScannedBeacons;
  NSDictionary *_beaconRegistrationData;

  UIViewController *_viewController;

  NSString *_moreButtonCellIdentifer;
  BOOL _shouldShowMoreButton;
}
@end

@implementation BeaconTableViewHelper

- (instancetype)initWithTableView:(UITableView *)tableView
                   viewController:(UIViewController *)viewController
         moreButtonCellIdentifier:(NSString *)moreButtonCellIdentifier {
  if ((self = [super init]) != nil) {
    _tableView = tableView;
    _viewController = viewController;

    _tableView.dataSource = self;
    _tableView.delegate = self;

    _moreButtonCellIdentifer = moreButtonCellIdentifier;
  }

  return self;
}

- (NSArray *)scannedBeaconList {
  return _recentlyScannedBeacons;
}

- (NSDictionary *)beaconRegistrationData {
  return _beaconRegistrationData;
}

- (void)setScannedBeaconList:(NSArray *)recentlyScannedBeacons {
  _recentlyScannedBeacons = recentlyScannedBeacons;
  [_tableView reloadData];
}

- (void)setBeaconRegistrationData:(NSDictionary *)registrationData {
  _beaconRegistrationData = registrationData;
  [_tableView reloadData];
}

- (void)setShouldShowMoreButton:(BOOL)shouldShowMoreButton {
  _shouldShowMoreButton = shouldShowMoreButton;
  [_tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (!_shouldShowMoreButton) {
    return [_recentlyScannedBeacons count];
  } else {
    return [_recentlyScannedBeacons count] + 1;
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [_viewController performSegueWithIdentifier:kShowRegisterBeaconSegueName sender:self];
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row < [_recentlyScannedBeacons count]) {
    UITableViewCell *cell;
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:kCellIdentifier];
    cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:13.0];

    NSString *bid = _recentlyScannedBeacons[indexPath.row];
    cell.textLabel.text = bid;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    BOOL disable = YES;
    if (_beaconRegistrationData[bid]) {
      id requestError = _beaconRegistrationData[bid][kRequestErrorStatus];

      // If it's ours and registered, or not registered at all, then we'll enable the row so
      // people can view / edit the beacon information. Otherwise, we can't do much with it and
      // will disable the cell.
      if (requestError && [requestError isEqualToString:@"NOT_FOUND"]) {
        cell.imageView.image = [UIImage imageNamed:@"add"];
        disable = NO;
      } else if (requestError && [requestError isEqualToString:@"PERMISSION_DENIED"]) {
        cell.imageView.image = [UIImage imageNamed:@"locked"];
      } else if (!requestError
                 && [_beaconRegistrationData[bid][@"status"]
                     isEqualToString:kEddystoneStatusDecommissioned]) {
                   cell.imageView.image = [UIImage imageNamed:@"cross"];
                 } else if (!requestError) {
                   cell.imageView.image = [UIImage imageNamed:@"tick"];
                   disable = NO;
                 }
    }

    if (disable) {
      cell.userInteractionEnabled = NO;
      cell.textLabel.enabled = NO;
      cell.detailTextLabel.enabled = NO;
    }
    return cell;

  } else {
    return [tableView dequeueReusableCellWithIdentifier:_moreButtonCellIdentifer];
  }
}

/**
 * Tell the incoming view controller the beaconID of the selected row if we're doing a
 * show register beacon segue.
 */
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:kShowRegisterBeaconSegueName]) {
    NSIndexPath *indexPath = [_tableView indexPathForSelectedRow];
    NSString *beaconID = [_tableView cellForRowAtIndexPath:indexPath].textLabel.text;
    RegisterBeaconViewController *vc = segue.destinationViewController;
    vc.beaconID = beaconID;
    vc.delegate = self;

    // If we have some registration data for this beacon, pass it to the new VC.
    if (!_beaconRegistrationData[beaconID][kRequestErrorStatus]) {
      vc.beaconData = _beaconRegistrationData[beaconID];
    }
  }
}

- (void)beaconRegistrator:(RegisterBeaconViewController *)registrator
      didUpdateBeaconInfo:(NSDictionary *)beaconInfo
              forBeaconID:(NSString *)beaconID {
  NSMutableDictionary *updated =
      [NSMutableDictionary dictionaryWithDictionary:_beaconRegistrationData];

  for (NSString *key in _beaconRegistrationData) {
    NSString *processedKey = [key stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *incomingBeaconID = [self extractBeaconID:beaconInfo[@"beaconName"]];
    if ([processedKey isEqualToString:incomingBeaconID]) {
      [updated setObject:beaconInfo forKey:key];
      break;
    }
  }

  // Reload the tableview in case the status values changed and we need a new icon now.
  dispatch_async(dispatch_get_main_queue(), ^() {
    _beaconRegistrationData = updated;
    [_tableView reloadData];
  });
}

- (NSString *)extractBeaconID:(NSString *)beaconName {
  NSArray *parts = [beaconName componentsSeparatedByString:@"!"];
  if ([parts count] == 2) {
    return parts[1];
  } else {
    return nil;
  }
}

@end
