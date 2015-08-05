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
#import "BeaconTableViewHelper.h"
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

/**
 *=-----------------------------------------------------------------------------------------------=
 * Private Additions to FirstViewController
 *=-----------------------------------------------------------------------------------------------=
 */
@interface FirstViewController () <ESSBeaconScannerDelegate> {
  GIDSignInButton *_signInButton;
  UIActivityIndicatorView *_signInStatusIndicator;
  NSMutableArray *_foundBeacons;

  ESSBeaconScanner *_scanner;

  BeaconTableViewHelper *_tableViewHelper;
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

  _tableViewHelper = [[BeaconTableViewHelper alloc] initWithTableView:_beaconListTableView
                                                       viewController:self
                                             moreButtonCellIdentifier:nil];

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

- (UIStatusBarStyle) preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)loginStatusChangedNotification:(NSNotification *)notification {
  [self updateUIForSignInStatus];
}

- (void)updateUIForSignInStatus {
  AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

  // If we're not logged in yet, throb if we're determining the status, otherwise show the Google
  // sign in button.
  if (appDelegate.signInStatus != kBSDLoginStatusLoggedIn) {

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
  _foundBeacons = [NSMutableArray array];
  [_tableViewHelper setScannedBeaconList:nil];
  [_tableViewHelper setBeaconRegistrationData:nil];

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
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"39fe899d70da4bb6966d36ab513ee12c"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"281ef01399614dfbab617395bb0d111b"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"0edb97fe36a44f90863ad35bc2fde262"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"f5239377a6eb4767b8892fbd0388bfc6"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"d7398ce574b24fc3bb9ff9eaa5e89da1"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"766f65043b044cccbd6f8d62de10db29"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"cf0a44777dd04a428c918484ea70fd49"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"394bbdd8d15a44cb8d910697460b4ee4"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"f2c42e94ee984e85bb0aaf222b01348b"]];
  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@"b77f90dc50814d24884bc9fe4e21b9ae"]];

  // This will show up with a lock -- it's registered by somebody else so you can't touch it
  [_foundBeacons addObject:[ESSBeaconInfo
      testBeaconFromBeaconIDString:@"6e131d091c10a9a04f2c34b9ab1cb791"]];

#endif // SHOW_SOME_FAKE_BEACONIDS_FOR_TESTING

  _pageTitle.text = @"Loading Data";

  NSMutableArray *ids = [NSMutableArray arrayWithCapacity:[_foundBeacons count]];
  for (ESSBeaconInfo *info in _foundBeacons) {
    [ids addObject:PrintableBeaconIDFromData(info.beaconID.beaconID)];
  }

  [_tableViewHelper setScannedBeaconList:ids];

  [BSDAdminAPI informationForSpecifiedBeaconIDs:ids completionHandler:
      ^(NSDictionary *results, NSDictionary *errorInfo) {

        NSLog(@"%@", results);

        // Reloading the tableview from within this block seems to be a terrible idea as it seems
        // to keep a lot of references on a whole lot of things that take a while to unroll. So,
        // instead, we'll just post a message to the main thread telling it to finish processing
        // once we've unrolled the stack, etc.
        dispatch_async(dispatch_get_main_queue(), ^{
          [self finishBeaconIDLoad: results];
        });
      }
  ];

  _foundBeacons = nil;
}

- (void)finishBeaconIDLoad:(NSDictionary *)beaconRegistrationData {
  [_scanningThrobber stopAnimating];
  _scanningThrobber.hidden = YES;
  _scanForBeaconsButton.enabled = YES;
  _pageTitle.text = @"Discovered Beacons";
  [_tableViewHelper setBeaconRegistrationData:beaconRegistrationData];
}


- (IBAction)unwindToContainerVC:(UIStoryboardSegue *)segue {
  // Don't actually need to do anything here.
}

/// TODO(marcwan): This isn't the cleanest of designs. Is there a better way?
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  [_tableViewHelper prepareForSegue:segue sender:sender];
}

@end
