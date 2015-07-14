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

#import "FirstViewController.h"

#import "AppDelegate.h"
#import "ESSEddystone.h"
#import "ESSBeaconScanner.h"
#import "RegisterBeaconViewController.h"

#import "BSDAdminAPI.h"

/**
 * One of the best ways to make sure that everything is running properly is to run this app in
 * the simulator. Since the simulator doesn't support Bluetooth scanning, we can, instead, have
 * the app "see" some fake Eddystone devices when you click "Scan". To do this, you should run
 * the following in your root BeaconServiceDemoApp folder:

 * # php gen_fake_beacons.php

 * Now when you build and run the simulator, there will be 10 beacons that you can play around
 * with registering, activating, deactiving, etc, and be able to verify that everything is
 * working properly before actually modifying real-world beacon hardware.
 *
 * For production or running on real devices, just comment out the define below.
 */
#define SHOW_SOME_FAKE_BEACONIDS_FOR_TESTING

/**
 * Since the simulator can't use bluetooth, we don't need to really make people wait all that long.
 * But, it's still a good idea to use the simulator, because you can fake beacons and test all of
 * the important functionality of the API.
 */
#if TARGET_IPHONE_SIMULATOR
static const NSTimeInterval kScanForThisLong = 1.0;
#else
static const NSTimeInterval kScanForThisLong = 5.0;
#endif // TARGET_IPHONE_SIMULATOR

static NSString *const kCellIdentifier = @"table_view_cell";
static NSString *const kShowRegisterBeaconSegueName = @"ShowRegisterBeaconSegue";

/**
 *=-----------------------------------------------------------------------------------------------=
 * Private Additions to FirstViewController
 *=-----------------------------------------------------------------------------------------------=
 */
@interface FirstViewController () <ESSBeaconScannerDelegate, RegisterBeaconViewControllerDelegate> {
  GIDSignInButton *_signInButton;
  UIActivityIndicatorView *_signInStatusIndicator;
  NSArray *_recentlyScannedBeacons;
  NSMutableArray *_foundBeacons;

  ESSBeaconScanner *_scanner;

  NSDictionary *_beaconRegistrationData;
}

@property (strong, nonatomic) IBOutlet UIView *unsignedInView;
@property (strong, nonatomic) IBOutlet UILabel *pageTitle;
@property (strong, nonatomic) IBOutlet UITableView *beaconListTableView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *scanningThrobber;
@property (strong, nonatomic) IBOutlet UIButton *scanForBeaconsButton;

- (void)loginStatusChangedNotification:(NSNotification *)notification;

@end

/**
 *=-----------------------------------------------------------------------------------------------=
 * Implementation of FirstViewController
 *=-----------------------------------------------------------------------------------------------=
 */
@implementation FirstViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  _scanningThrobber.hidden = YES;

  _unsignedInView = [[UIView alloc] init];
  _unsignedInView.frame = self.view.frame;
  _unsignedInView.backgroundColor = [UIColor whiteColor];
  [self.view addSubview:_unsignedInView];
  [self.view bringSubviewToFront:_unsignedInView];
  _unsignedInView.hidden = NO;

  CGSize viewf = _unsignedInView.frame.size;

  // The GIDSignInButton doesn't seemto play well just yet in storyboards, so we'll just create
  // it here in code.
  if (!_signInButton) {
    _signInButton = [[GIDSignInButton alloc] init];
    [_unsignedInView addSubview:_signInButton];
    CGRect r;
    r.origin.x = (viewf.width / 2) - 75;
    r.origin.y = viewf.height / 2 - 20;
    r.size.width = 150;
    r.size.height = 40;
    _signInButton.frame = r;
  }

  if (!_signInStatusIndicator) {
    _signInStatusIndicator = [[UIActivityIndicatorView alloc] init];
    _signInStatusIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [_unsignedInView addSubview:_signInStatusIndicator];
    CGRect r;
    r.origin.x = (viewf.width / 2) - 40;
    r.origin.y = viewf.height / 2 - 40;
    r.size.width = 80;
    r.size.height = 80;
    _signInStatusIndicator.frame = r;
  }

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(loginStatusChangedNotification:)
                                               name:kBSDLoginStatusChangedNotification
                                             object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  [GIDSignIn sharedInstance].uiDelegate = self;
}

- (void)loginStatusChangedNotification:(NSNotification *)notification {
  [self updateUIForSignInStatus];
}

- (void)updateUIForSignInStatus {
  AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

  // If we're not logged in yet, throb if we're determining the status, otherwise show the Google
  // sign in button.
  if (appDelegate.signInStatus != kBSDLoginStatusLoggedIn) {
    _recentlyScannedBeacons = nil;

    if (appDelegate.signInStatus == kBSDLoginStatusDetermining) {
      _signInButton.hidden = YES;
      _signInStatusIndicator.hidden = NO;
      [_signInStatusIndicator startAnimating];
    } else {
      _signInStatusIndicator.hidden = YES;
      _signInButton.hidden = NO;
    }

    if (_unsignedInView.hidden == YES) {
      _unsignedInView.alpha = 0;
      _unsignedInView.hidden = NO;
      [UIView animateWithDuration:0.3 animations:^{
        _unsignedInView.alpha = 1;
      } completion: ^(BOOL finished) {
      }];
    }
  } else if (appDelegate.signInStatus == kBSDLoginStatusLoggedIn) {
    if (_unsignedInView.hidden == NO) {
      [UIView animateWithDuration:0.3 animations:^{
        _unsignedInView.alpha = 0;
      } completion: ^(BOOL finished) {
        _unsignedInView.hidden = finished;
      }];
    }
  }
}

- (IBAction)scanForBeaconsPressed:(id)sender {

  _pageTitle.text = @"Scanning …";
  _beaconRegistrationData = nil;
  _foundBeacons = [NSMutableArray array];
  _recentlyScannedBeacons = nil;

  // Clear the tableview while we're scanning.
  [_beaconListTableView reloadData];

  // UI Feedback for scanning.
  _scanForBeaconsButton.enabled = NO;
  _scanningThrobber.hidden = NO;
  [_scanningThrobber startAnimating];

  _scanner = [[ESSBeaconScanner alloc] init];
  _scanner.delegate = self;
  [_scanner startScanning];

  [NSTimer scheduledTimerWithTimeInterval:kScanForThisLong
                                   target:self
                                 selector:@selector(stopScanningNow:)
                                 userInfo:nil
                                  repeats:NO];
}

- (IBAction)logoutPressed:(id)sender {
  [[GIDSignIn sharedInstance] disconnect];
}

- (void)beaconScanner:(ESSBeaconScanner *)scanner didFindBeacon:(id)beaconInfo {
  [_foundBeacons addObject:beaconInfo];
}

- (void)stopScanningNow:(NSTimer *)timer {
  [_scanner stopScanning];

#ifdef SHOW_SOME_FAKE_BEACONIDS_FOR_TESTING

  // This will show up with a lock -- it's registered by somebody else so you can't touch it
  [_foundBeacons addObject:[ESSBeaconInfo
      testBeaconFromBeaconIDString:@"6e131d091c10a9a04f2c34b9ab1cb791"]];



#endif // SHOW_SOME_FAKE_BEACONIDS_FOR_TESTING

  _recentlyScannedBeacons = _foundBeacons;
  _foundBeacons = nil;

  [_beaconListTableView reloadData];

  _pageTitle.text = @"Loading Data";

  NSMutableArray *ids = [NSMutableArray arrayWithCapacity:[_recentlyScannedBeacons count]];
  for (ESSBeaconInfo *info in _recentlyScannedBeacons) {
    NSString *bid = [NSString stringWithFormat:@"%@", info.beaconID.beaconID];

    bid = [bid substringWithRange:NSMakeRange(1, [bid length] - 2)];
    [ids addObject:bid];
  }

  [BSDAdminAPI informationForSpecifiedBeaconIDs:ids completionHandler:
      ^(NSDictionary *results, NSDictionary *errorInfo) {
        _beaconRegistrationData = results;

        // Reloading the tableview from within this block seems to be a terrible idea as it seems
        // to keep a lot of references on a whole lot of things that take a while to unroll. So,
        // instead, we'll just post a message to the main thread telling it to finish processing
        // once we've unrolled the stack, etc.
        dispatch_async(dispatch_get_main_queue(), ^{
          [self finishBeaconIDLoad];
        });
      }
  ];
}

- (void)finishBeaconIDLoad {
  [_scanningThrobber stopAnimating];
  _scanningThrobber.hidden = YES;
  _scanForBeaconsButton.enabled = YES;
  _pageTitle.text = @"Discovered Beacons";
  [_beaconListTableView reloadData];

}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [_recentlyScannedBeacons count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [self performSegueWithIdentifier:kShowRegisterBeaconSegueName sender:self];
  [_beaconListTableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell;
  cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                reuseIdentifier:kCellIdentifier];
  cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:13.0];

  NSString *bid = [NSString stringWithFormat:@"%@",
                   ((ESSBeaconInfo *)_recentlyScannedBeacons[indexPath.row]).beaconID.beaconID];

  // Trim out the < > chars
  bid = [bid substringWithRange:NSMakeRange(1, [bid length] - 2)];
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
  [_beaconListTableView reloadData];
  });
}

/**
 * Tell the incoming view controller the beaconID of the selected row if we're doing a
 * show register beacon segue.
 */
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:kShowRegisterBeaconSegueName]) {
    NSIndexPath *indexPath = [_beaconListTableView indexPathForSelectedRow];
    NSString *beaconID = [_beaconListTableView cellForRowAtIndexPath:indexPath].textLabel.text;
    RegisterBeaconViewController *vc = segue.destinationViewController;
    vc.beaconID = beaconID;
    vc.delegate = self;

    // If we have some registration data for this beacon, pass it to the new VC.
    if (!_beaconRegistrationData[beaconID][kRequestErrorStatus]) {
      vc.beaconData = _beaconRegistrationData[beaconID];
    }
  }
}

- (IBAction)unwindToContainerVC:(UIStoryboardSegue *)segue {
  // Don't actually need to do anything here.
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
