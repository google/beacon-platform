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

#import <CoreLocation/CoreLocation.h>
@import GoogleMaps;

#import "SearchViewController.h"

#import "BeaconTableViewHelper.h"
#import "BSDAdminAPI.h"
#import "ESSEddystone.h"
#import "ListSelectionViewController.h"

static const int kBeaconsPerSearchPage = 20;

NSString *QuoteAndEscape(NSString *escape_me) {
  return [NSString stringWithFormat:@"\"%@\"",
          [escape_me stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}

NSString *EscapeQuotes(NSString *escape_me) {
  return [escape_me stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

@interface SearchViewController ()
    <UITextViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate, LSVCSelectionDelegate> {
  NSArray *_searchCriteria;

  UIView *_pickerViewHolder;
  UIPickerView *_criterionPicker;
  UIButton *_doneButton;

  NSString *_listSelectionFieldName;
  GMSPlacePicker *_placePicker;

  BeaconTableViewHelper *_tableViewHelper;

  // If the user has already run a query, we keep the query and page token so we can run it again
  // when the user clicks the "More..." button.
  NSString *_pageTokenQuery;
  NSString *_pageToken;
}

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UITextView *searchTextView;
@property (strong, nonatomic) IBOutlet UIView *hidingView;
@property (strong, nonatomic) IBOutlet UIButton *addCriteriaButton;
@property (strong, nonatomic) IBOutlet UIButton *searchNowButton;

@end

@implementation SearchViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  _tableViewHelper = [[BeaconTableViewHelper alloc] initWithTableView:_tableView
                                                       viewController:self
                                             moreButtonCellIdentifier:@"MoreButtonTableViewCell"];
  _searchCriteria = @[
      @"Description",
      @"Status",
      @"Stability",
      @"Place ID",
      @"Registration Time",
      @"Lat/Lon/Radius",
      @"Device Property",
      @"Attachment Type",
  ];

  _pickerViewHolder = [[UIView alloc] init];
  _pickerViewHolder.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];

  _criterionPicker = [[UIPickerView alloc] init];
  _criterionPicker.delegate = self;
  _criterionPicker.dataSource = self;
  [_pickerViewHolder addSubview:_criterionPicker];

  _doneButton = [[UIButton alloc] init];
  [_doneButton addTarget:self
                 action:@selector(doneButtonPressed:)
       forControlEvents:UIControlEventTouchUpInside];
  [_doneButton setTitle:@"Select" forState:UIControlStateNormal];
  [_doneButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];

  [_pickerViewHolder addSubview:_doneButton];
  [self.view addSubview:_pickerViewHolder];

  _searchTextView.clipsToBounds = YES;
  _searchTextView.layer.cornerRadius = 4.0f;
  _searchTextView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  CGRect r = self.view.frame;
  CGRect holderFrame = CGRectMake(0, r.size.height, r.size.width, 230);
  _pickerViewHolder.frame = holderFrame;
  _criterionPicker.frame = CGRectMake(0, 30, r.size.width, 180);
  _doneButton.frame = CGRectMake(r.size.width - 68, 8, 60, 30);

  _addCriteriaButton.enabled = YES;
  _searchNowButton.enabled = YES;
}

- (UIStatusBarStyle) preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

/// TODO: This isn't the cleanest of designs. Is there a better way?
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  [_tableViewHelper prepareForSegue:segue sender:sender];
}

- (NSString *)extractBeaconID:(NSString *)beaconName {
  NSArray *parts = [beaconName componentsSeparatedByString:@"!"];
  if ([parts count] == 2) {
    return parts[1];
  } else {
    return nil;
  }
}

#pragma mark - IBActions

- (IBAction)moreButtonPressed:(id)sender {
  [BSDAdminAPI listBeaconsWithCriteria:_pageTokenQuery
                             pageToken:_pageToken
                              pageSize:kBeaconsPerSearchPage
                     completionHandler:
      ^(NSArray *beacons, NSString *nextPageToken, int totalCount, NSDictionary *error) {
        if ([beacons count]) {
          // Extract the beaconids for the array of scanned beacons.
          NSMutableArray *bids =
              [NSMutableArray arrayWithArray:[_tableViewHelper scannedBeaconList]];
          NSMutableDictionary *beaconRegistrationData = [NSMutableDictionary
              dictionaryWithDictionary:[_tableViewHelper beaconRegistrationData]];

          for (NSDictionary *beaconInfo in beacons) {
            NSString *bid = [self extractBeaconID:beaconInfo[@"beaconName"]];
            if (bid) {
              NSString *printable = PrintableBeaconIDFromHexString(bid);
              [bids addObject:printable];
              beaconRegistrationData[printable] = beaconInfo;
            }
          }

          if (nextPageToken) {
            _pageTokenQuery = _searchTextView.text;
            _pageToken = nextPageToken;
          }

          // Now update our helper.
          dispatch_async(dispatch_get_main_queue(), ^{
            [_tableViewHelper setScannedBeaconList:bids];
            [_tableViewHelper setBeaconRegistrationData:beaconRegistrationData];
            if (nextPageToken) {
              [_tableViewHelper setShouldShowMoreButton:YES];
            }
          });
        }

        if ([beacons count] < kBeaconsPerSearchPage) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [_tableViewHelper setShouldShowMoreButton:NO];
          });
        }
      }
  ];
}

- (IBAction)searchNowButtonPressed:(id)sender {
  // First clear out and update some UI.
  _searchNowButton.enabled = NO;
  _addCriteriaButton.enabled = NO;
  _hidingView.hidden = NO;

  [_tableViewHelper setScannedBeaconList:nil];
  [_tableViewHelper setBeaconRegistrationData:nil];
  [_tableViewHelper setShouldShowMoreButton:NO];

  // Start searching.
  [BSDAdminAPI listBeaconsWithCriteria:_searchTextView.text
                             pageToken:nil
                              pageSize:kBeaconsPerSearchPage
                     completionHandler:
      ^(NSArray *beacons, NSString *nextPageToken, int totalCount, NSDictionary *error) {
        // Restore the UI.
        dispatch_async(dispatch_get_main_queue(), ^{
          _hidingView.hidden = YES;
          _searchNowButton.enabled = YES;
          _addCriteriaButton.enabled = YES;
        });

        if ([beacons count]) {
          // Extract the beaconids for the array of scanned beacons.
          NSMutableArray *beaconids = [NSMutableArray array];
          NSMutableDictionary *beaconRegistrationData = [NSMutableDictionary dictionary];
          for (NSDictionary *beaconInfo in beacons) {
            NSString *bid = [self extractBeaconID:beaconInfo[@"beaconName"]];
            if (bid) {
              NSString *printable = PrintableBeaconIDFromHexString(bid);
              [beaconids addObject:printable];
              beaconRegistrationData[printable] = beaconInfo;
            }
          }

          if (nextPageToken) {
            _pageTokenQuery = _searchTextView.text;
            _pageToken = nextPageToken;
          }

          // Now update our helper.
          dispatch_async(dispatch_get_main_queue(), ^{
            [_tableViewHelper setScannedBeaconList:beaconids];
            [_tableViewHelper setBeaconRegistrationData:beaconRegistrationData];
            if (nextPageToken) {
              [_tableViewHelper setShouldShowMoreButton:YES];
            }
          });
        }

        if ([beacons count] < kBeaconsPerSearchPage) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [_tableViewHelper setShouldShowMoreButton:NO];
          });
        }
      }
  ];
}

- (IBAction)doneButtonPressed:(id)sender {
  [UIView animateWithDuration:0.3f
                   animations:
      ^{
        CGRect r = _pickerViewHolder.frame;
        CGRect newr = CGRectMake(r.origin.x,
                                 r.origin.y + r.size.height,
                                 r.size.width,
                                 r.size.height);
        _pickerViewHolder.frame = newr;
        _addCriteriaButton.enabled = YES;
        _searchNowButton.enabled = YES;
      }
                  completion:
      ^(BOOL finished) {
        if (finished) {
          [self presentCriterionInputUI];
        }
      }
  ];
}

- (IBAction)addButtonPressed:(id)sender {
  _addCriteriaButton.enabled = NO;
  _searchNowButton.enabled = NO;

  [UIView animateWithDuration:0.3f animations:^{
    CGRect r = _pickerViewHolder.frame;
    CGRect newr = CGRectMake(r.origin.x, r.origin.y - r.size.height, r.size.width, r.size.height);
    _pickerViewHolder.frame = newr;
  }];
}

#pragma mark - Delegate and Data Source methods

/**
 * If you change the query, then the "More..." button is irrelevant and should be hidden.
 */
- (void)textViewDidChange:(UITextView *)textView {
  [_tableViewHelper setShouldShowMoreButton:NO];
}

- (void)listSelection:(ListSelectionViewController *)listSelection didSelectItem:(NSString *)item {
  if (_listSelectionFieldName) {
    [self addCriterionNamed:_listSelectionFieldName withValue:item];
    _listSelectionFieldName = nil;
  }
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
  return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
  return 8;
}

-(NSString *)pickerView:(UIPickerView *)pickerView
            titleForRow:(NSInteger)row
           forComponent:(NSInteger)component {
  if (row < [_searchCriteria count]) {
    return _searchCriteria[row];
  } else {
    NSLog(@"Asked for unexpected row in search picker");
    return @"";
  }
}

- (void)presentCriterionInputUI {
  switch ([_criterionPicker selectedRowInComponent:0]) {
    case 0:
      [self collectAndAddDescription];
      break;
    case 1:
      [self collectAndAddStatus];
      break;
    case 2:
      [self collectAndAddStability];
      break;
    case 3:
      [self collectAndAddPlaceID];
      break;
    case 4:
      [self collectAndAddRegistrationTime];
      break;
    case 5:
      [self collectAndAddLatLngRadius];
      break;
    case 6:
      [self collectAndAddRegisteredProperty];
      break;
    case 7:
      [self collectAndAddAttachmentType];
      break;
  }
}

- (void)addCriterionNamed:(NSString *)criterionName withValue:(NSString *)value {
  [self addCriterionNamed:criterionName withValue:value operator:@":"];
}

- (void)addCriterionNamed:(NSString *)criterionName
                withValue:(NSString *)value
                 operator:(NSString *)operator {
  NSString *pair = [NSString stringWithFormat:@"%@%@%@ ", criterionName, operator, value];
  _searchTextView.text = [_searchTextView.text stringByAppendingString:pair];
  [_tableViewHelper setShouldShowMoreButton:NO];
}

- (void)presentTextInputsWithTitle:(NSString *)title
                            label1:(NSString *)label1
                            label2:(NSString *)label2
                            label3:(NSString *)label3
                       description:(NSString *)description
                          callback:(void (^)(NSArray *))callback {
  if ([UIAlertController class]) {
    UIAlertController *alert= [UIAlertController
                               alertControllerWithTitle:title
                               message:description
                               preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                               handler:
        ^(UIAlertAction * action) {
          NSMutableArray *values = [NSMutableArray array];
          for (UITextField *textField in alert.textFields) {
            [values addObject:textField.text];
          }
          callback(values);
        }
    ];
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                   handler:
        ^(UIAlertAction * action) {
          [alert dismissViewControllerAnimated:YES completion:nil];
        }
    ];

    [alert addAction:ok];
    [alert addAction:cancel];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
      textField.placeholder = label1;
      textField.keyboardType = UIKeyboardTypeDefault;
    }];
    if (label2) {
      [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = label2;
        textField.keyboardType = UIKeyboardTypeDefault;
      }];
    }
    if (label2 && label3) {
      [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = label3;
        textField.keyboardType = UIKeyboardTypeDefault;
      }];
    }

    [self presentViewController:alert animated:YES completion:nil];
  }
}

- (void)collectAndAddPlaceID {
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake(51.5072, 0.1275);

  CLLocationCoordinate2D northEast = CLLocationCoordinate2DMake(center.latitude + 0.001,
                                                                center.longitude + 0.001);
  CLLocationCoordinate2D southWest = CLLocationCoordinate2DMake(center.latitude - 0.001,
                                                                center.longitude - 0.001);
  GMSCoordinateBounds *viewport = [[GMSCoordinateBounds alloc] initWithCoordinate:northEast
                                                                       coordinate:southWest];
  GMSPlacePickerConfig *config = [[GMSPlacePickerConfig alloc] initWithViewport:viewport];
  _placePicker = [[GMSPlacePicker alloc] initWithConfig:config];

  [_placePicker pickPlaceWithCallback:^(GMSPlace *place, NSError *error) {
    if (error != nil) {
      NSLog(@"Pick Place error %@", [error localizedDescription]);
      return;
    }

    if (place) {
      [self addCriterionNamed:@"place_id" withValue:QuoteAndEscape(place.placeID)];
      _placePicker = nil;
    }
  }];
}

- (void)collectAndAddDescription {
  [self presentTextInputsWithTitle:@"Description"
                            label1:@"description"
                            label2:nil
                            label3:nil
                       description:
      @"Value to match in description property of registered beacons"
                          callback:
      ^(NSArray *values) {
        if (values[0]) {
          [self addCriterionNamed:@"description" withValue:QuoteAndEscape(values[0])];
        }
      }
  ];
}

- (void)collectAndAddStatus {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  ListSelectionViewController *vc =
      [storyboard instantiateViewControllerWithIdentifier:@"ListSelectionViewController"];
  vc.itemsToDisplay = @[
      @"ACTIVE",
      @"INACTIVE",
      @"DECOMMISSIONED",
  ];
  vc.titleText = @"Status";
  vc.delegate = self;
  _listSelectionFieldName = @"status";
  [self presentViewController:vc animated:YES completion:nil];
}

- (void)collectAndAddStability {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  ListSelectionViewController *vc =
      [storyboard instantiateViewControllerWithIdentifier:@"ListSelectionViewController"];
  vc.itemsToDisplay = @[
      @"STABLE",
      @"PORTABLE",
      @"MOBILE",
      @"ROVING"
  ];
  vc.titleText = @"Expected Stability";
  vc.delegate = self;
  _listSelectionFieldName = @"stability";
  [self presentViewController:vc animated:YES completion:nil];
}

- (void)collectAndAddRegistrationTime {
  [self presentTextInputsWithTitle:@"Registration Time"
                            label1:@"start_time"
                            label2:@"end_time"
                            label3:nil
                       description:
      @"Registration time in seconds since Epoch. Can specify one or both. Values inclusive"
                          callback:
      ^(NSArray *values) {
        if (values) {
          if ([(NSString *)values[0] length]) {
            [self addCriterionNamed:@"registration_time" withValue:values[0] operator:@">="];
          }
          if ([(NSString *)values[1] length]) {
            [self addCriterionNamed:@"registration_time" withValue:values[1] operator:@"<="];
          }
        }
      }
  ];
}

- (void)collectAndAddLatLngRadius {
  [self presentTextInputsWithTitle:@"Lat / Lon : Radius"
                            label1:@"latitude"
                            label2:@"longitude"
                            label3:@"radius"
                       description:
      @"Latitude and longitude for the beacon, with a radius specified in metres. "
      @"All fields mandatory!"
                          callback:
      ^(NSArray *values) {
        if ([values count] >= 3) {
          [self addCriterionNamed:@"lat" withValue:QuoteAndEscape(values[0])];
          [self addCriterionNamed:@"lng" withValue:QuoteAndEscape(values[1])];
          [self addCriterionNamed:@"radius" withValue:QuoteAndEscape(values[2])];
        }
      }
  ];
}

- (void)collectAndAddRegisteredProperty {
  [self presentTextInputsWithTitle:@"Registered Property"
                             label1:@"property_name"
                             label2:@"property_value"
                             label3:nil
                        description:
       @"A beacon property name and value previously registered for the beacon"
                           callback:
       ^(NSArray *values) {
         if ([values count] >= 2) {
           NSString *propval = [NSString stringWithFormat:@"\"%@=%@\"",
               EscapeQuotes(values[0]),
               EscapeQuotes(values[1])];
           [self addCriterionNamed:@"property" withValue:propval];
         }
       }
  ];
}

- (void)collectAndAddAttachmentType {
  [self presentTextInputsWithTitle:@"Attachment Type"
                            label1:@"attachment_type"
                            label2:nil
                            label3:nil
                       description:
      @"Namespaced type to search for. For example, 'namespace/type', or 'namespace/*'"
                          callback:
      ^(NSArray *values) {
        if (values[0]) {
          [self addCriterionNamed:@"attachment_type" withValue:QuoteAndEscape(values[0])];
        }
      }
  ];
}

@end
