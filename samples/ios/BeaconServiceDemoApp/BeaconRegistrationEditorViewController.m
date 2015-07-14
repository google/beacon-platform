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

#import "BeaconRegistrationEditorViewController.h"

#import "LatLngViewController.h"
#import "ListSelectionViewController.h"
#import "BSDAdminAPI.h"

@interface BeaconRegistrationEditorViewController ()
    <LSVCSelectionDelegate, LLVCSelectionDelegate> {
  BOOL _listSelectViewControllerActive;
  CLLocationManager *_locationManager;
  GMSPlacePicker *_placePicker;

  /**
   * If this is set, then the beacon is (to be) associated with a PlaceID instead of a simple
   * lat/lon coordinate.
   */
  GMSPlace *_pickedPlace;
}
@property (strong, nonatomic) IBOutlet UIButton *cancelButton;
@property (strong, nonatomic) IBOutlet UIButton *saveButton;
@property (strong, nonatomic) IBOutlet UITextField *stabilityTextField;
@property (strong, nonatomic) IBOutlet UITextField *locationTextField;
@property (strong, nonatomic) IBOutlet UIButton *activateBeaconButton;
@property (strong, nonatomic) IBOutlet UIButton *decommissionBeaconButton;
@property (strong, nonatomic) IBOutlet UIButton *useCurrentLocationButton;

@end

@implementation BeaconRegistrationEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

  // Are we registering a new beacon?
  if (!_existingBeaconInfo) {
    _locationTextField.text = @"0.0,0.0";
    _activateBeaconButton.hidden = YES;
    _decommissionBeaconButton.hidden = YES;
  } else {
    // If we were given a PlaceID, then we have to call into the places SDK to convert that into
    // a name. Otherwise, just parse out the lat/lon they give us.
    if (_existingBeaconInfo[@"placeId"]) {
      [[GMSPlacesClient sharedClient] lookUpPlaceID:_existingBeaconInfo[@"placeId"] callback:
          ^(GMSPlace *place, NSError *error) {
            if (!error) {
              _pickedPlace = place;
              _locationTextField.text = place.name;
            } else {
              // TODO(developer): Maybe report the error here and try again?
              _locationTextField.text = @"0.0,0.0";
            }
          }
      ];
    } else {
      // Just a lat/lon, no worries!
      _locationTextField.text = [NSString stringWithFormat:@"%@,%@",
          _existingBeaconInfo[@"latLng"][@"latitude"],
          _existingBeaconInfo[@"latLng"][@"longitude"]];
    }
      _stabilityTextField.text = _existingBeaconInfo[@"stability"];
    [_saveButton setTitle:@"Update" forState:UIControlStateNormal];
    [_saveButton setTitle:@"Update" forState:UIControlStateSelected];
    [_saveButton setTitle:@"Update" forState:UIControlStateHighlighted];

    if ([_existingBeaconInfo[@"status"] isEqualToString:@"INACTIVE"]) {
      [_activateBeaconButton setTitle:@"Activate this Beacon" forState:UIControlStateNormal];
      [_activateBeaconButton setTitle:@"Activate this Beacon" forState:UIControlStateSelected];
      [_activateBeaconButton setTitle:@"Activate this Beacon" forState:UIControlStateHighlighted];
    }
  }

  // Start geting location updates now so we'll have decent values for when the user asks for them.
  _locationManager = [[CLLocationManager alloc] init];
  if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
    [_locationManager requestWhenInUseAuthorization];
  }
  [_locationManager startUpdatingLocation];

  // Finally, set expected stability
  if (_existingBeaconInfo[@"expectedStability"]) {
    _stabilityTextField.text = _existingBeaconInfo[@"expectedStability"];
  }
}

#pragma mark - IBActions

- (IBAction)cancelButtonPressed:(id)sender {
  [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)saveButtonPressed:(id)sender {
  BOOL creating = (_existingBeaconInfo == nil);

  void (^returnBlock)(NSDictionary *beaconInfo, NSDictionary *errorInfo) =
      ^(NSDictionary *beaconInfo, NSDictionary *errorInfo) {
        if (errorInfo) {
          NSString *title, *message;

          if (errorInfo[kRequestErrorMessage]) {
            message = errorInfo[kRequestErrorMessage];
            title = errorInfo[kRequestErrorStatus];
          } else {
            title = @"Unexpected error";
            message = errorInfo[kRequestErrorStatus];
          }
          UIAlertController* alert =
          [UIAlertController alertControllerWithTitle:title
                                              message:message
                                       preferredStyle:UIAlertControllerStyleAlert];

          UIAlertAction* defaultAction =
          [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {}];

          [alert addAction:defaultAction];
          [self presentViewController:alert animated:YES completion:nil];
          return;
        } else if (creating) {
          if ([_delegate
               respondsToSelector:@selector(beaconRegistrationEditor:didRegisterBeacon:)]) {
            [_delegate beaconRegistrationEditor:self didRegisterBeacon:beaconInfo];
          }
          [self dismissViewControllerAnimated:YES completion:NULL];
        } else {
          if ([_delegate
               respondsToSelector:@selector(beaconRegistrationEditor:didUpdateBeacon:)]) {
            [_delegate beaconRegistrationEditor:self didUpdateBeacon:beaconInfo];
          }
          [self dismissViewControllerAnimated:YES completion:NULL];
        }
  };

  if (!_existingBeaconInfo) {
    if (_pickedPlace) {
      [BSDAdminAPI registerBeaconWithBeaconID:_beaconID
                                      placeID:_pickedPlace.placeID
                                    stability:_stabilityTextField.text
                            completionHandler:returnBlock];
    } else {
      [BSDAdminAPI registerBeaconWithBeaconID:_beaconID
                                     latitude:@([self latitudeFromTextField])
                                    longitude:@([self longitudeFromTextField])
                                    stability:_stabilityTextField.text
                            completionHandler:returnBlock];
    }
  } else {
    if (_pickedPlace) {
      [BSDAdminAPI updateBeaconWithBeaconID:_beaconID
                                    placeID:_pickedPlace.placeID
                                  stability:_stabilityTextField.text
                          completionHandler:returnBlock];
    } else {
      [BSDAdminAPI updateBeaconWithBeaconID:_beaconID
                                   latitude:@([self latitudeFromTextField])
                                  longitude:@([self longitudeFromTextField])
                                  stability:_stabilityTextField.text
                          completionHandler:returnBlock];
    }
  }
}

- (IBAction)activateButtonPressed:(id)sender {
  NSString *currentStatus = _existingBeaconInfo[@"status"];
  _activateBeaconButton.enabled = NO;
  _cancelButton.enabled = NO;
  _saveButton.enabled = NO;

  void (^resultsBlock)(NSDictionary *) = ^(NSDictionary *errorInfo) {
    if (!errorInfo) {
      NSMutableDictionary *updated =
      [NSMutableDictionary dictionaryWithDictionary:_existingBeaconInfo];
      if ([currentStatus isEqualToString:@"ACTIVE"]) {
        updated[@"status"] = @"INACTIVE";
      } else {
        updated[@"status"] = @"ACTIVE";
      }
      _existingBeaconInfo = updated;
      if ([_delegate
           respondsToSelector:@selector(beaconRegistrationEditor:didUpdateBeacon:)]) {
        [_delegate beaconRegistrationEditor:self didUpdateBeacon:updated];
      }

      // This is a major change, so we'll dismiss this view controller.
      [self dismissViewControllerAnimated:YES completion:NULL];
    } else {
      NSString *title, *message;

      if (errorInfo[kRequestErrorMessage]) {
        message = errorInfo[kRequestErrorMessage];
        title = errorInfo[kRequestErrorStatus];
      } else {
        title = @"Unexpected error";
        message = errorInfo[kRequestErrorStatus];
      }
      UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];

      UIAlertAction* defaultAction =
      [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action) {}];

      [alert addAction:defaultAction];
      [self presentViewController:alert animated:YES completion:nil];
      _activateBeaconButton.enabled = YES;
      _cancelButton.enabled = YES;
      _saveButton.enabled = YES;
      return;
    }
  };

  if ([_existingBeaconInfo[@"status"] isEqualToString:@"ACTIVE"]) {
    [BSDAdminAPI deactivateBeaconWithBeaconID:_beaconID completionHandler:resultsBlock];
  } else {
    [BSDAdminAPI activateBeaconWithBeaconID:_beaconID completionHandler:resultsBlock];
  }
}

- (IBAction)decommissionButtonPressed:(id)sender {
  UIAlertController *alertController;
  UIAlertAction *decommissionAction;
  UIAlertAction *otherAction;

  _saveButton.enabled = NO;
  _cancelButton.enabled = NO;

  alertController = [UIAlertController alertControllerWithTitle:@"Decommission this beacon?"
                                                        message:@"This operation cannot be undone."
                                                 preferredStyle:
                     UIAlertControllerStyleActionSheet];

  decommissionAction = [UIAlertAction actionWithTitle:@"Decommission"
                                                style:UIAlertActionStyleDestructive
                                              handler:
      ^(UIAlertAction *action) {
                     // Disable this for network access.
                     _saveButton.enabled = NO;

        [BSDAdminAPI decommissionBeaconWithBeaconID:_beaconID completionHandler:
            ^(NSDictionary *errorInfo) {
              if (!errorInfo) {
                NSMutableDictionary *updated =
                [NSMutableDictionary dictionaryWithDictionary:_existingBeaconInfo];
                updated[@"status"] = @"UNREGISTERED";
                _existingBeaconInfo = updated;
                if ([_delegate
                     respondsToSelector:@selector(beaconRegistrationEditor:didUpdateBeacon:)]) {
                  [_delegate beaconRegistrationEditor:self didUpdateBeacon:updated];
                }

                // This is a major change, so we'll dismiss this view controller.
                [self performSegueWithIdentifier:@"AbandonAllBeaconEditsSegue" sender:self];
              } else {
                NSString *title, *message;

                if (errorInfo[kRequestErrorMessage]) {
                  message = errorInfo[kRequestErrorMessage];
                  title = errorInfo[kRequestErrorStatus];
                } else {
                  title = @"Unexpected error";
                  message = errorInfo[kRequestErrorStatus];
                }
                UIAlertController* alert =
                [UIAlertController alertControllerWithTitle:title
                                                    message:message
                                             preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction* defaultAction =
                [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction * action) {}];

                [alert addAction:defaultAction];
                [self presentViewController:alert animated:YES completion:nil];
                _saveButton.enabled = YES;
                _cancelButton.enabled = YES;
                return;
              }
            }
         ];
      }
  ];

  otherAction = [UIAlertAction actionWithTitle:@"Cancel"
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action) {
                                         _saveButton.enabled = YES;
                                         _cancelButton.enabled = YES;
                                       }];
  
  [alertController addAction:decommissionAction];
  [alertController addAction:otherAction];
  [alertController setModalPresentationStyle:UIModalPresentationPopover];
  
  [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - delegate protocol invocations

- (void)latLngEntry:(LatLngViewController *)viewController
   didEnterLatitude:(double)latitude
          longitude:(double)longitude {
  _locationTextField.text = [NSString stringWithFormat:@"%g,%g", latitude, longitude];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  if (textField == _stabilityTextField) {
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
    _listSelectViewControllerActive = YES;
    [self presentViewController:vc animated:YES completion:nil];
  } else if (textField == _locationTextField) {
    [self locationTextFieldStartEditing];
  }
  
  return NO;
}

/**
 * Called when the view controller is dismissing itself.
 */
- (void)listSelection:(ListSelectionViewController *)listSelection didSelectItem:(NSString *)item {
  if (_listSelectViewControllerActive) {
    _stabilityTextField.text = item;
    _listSelectViewControllerActive = NO;
  }
}

#pragma mark - Other Methods

- (void)locationTextFieldStartEditing {
  UIAlertController *alertController;
  UIAlertAction *pickPlaceAction, *currentLocationAction, *chooseLocationAction, *otherAction;

  alertController = [UIAlertController alertControllerWithTitle:@"Change Location"
                                                        message:@"How will you enter your location?"
                                                 preferredStyle:UIAlertControllerStyleActionSheet];

  pickPlaceAction = [UIAlertAction actionWithTitle:@"Pick Place"
                                             style:UIAlertActionStyleDefault
                                           handler:
      ^(UIAlertAction *action) {

        CLLocationCoordinate2D center = CLLocationCoordinate2DMake(
            _locationManager.location.coordinate.latitude,
            _locationManager.location.coordinate.longitude);

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
            _pickedPlace = place;
            _locationTextField.text = place.name;
          }
        }];

      }
  ];

  currentLocationAction = [UIAlertAction actionWithTitle:@"Use Current Location"
                                                   style:UIAlertActionStyleDefault
                                                 handler:
      ^(UIAlertAction *action) {
        _pickedPlace = nil;
        _locationTextField.text = [NSString stringWithFormat:@"%f,%f",
                                   _locationManager.location.coordinate.latitude,
                                   _locationManager.location.coordinate.longitude];
      }
  ];

  chooseLocationAction = [UIAlertAction actionWithTitle:@"Manually Select Location"
                                                  style:UIAlertActionStyleDefault
                                                handler:
      ^(UIAlertAction *action) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        LatLngViewController *vc =
        [storyboard instantiateViewControllerWithIdentifier:@"LatLngViewController"];

        // If they were using a place, extract the lat/lon.
        if (_pickedPlace) {
          vc.latitude = _pickedPlace.coordinate.latitude;
          vc.longitude = _pickedPlace.coordinate.longitude;
        } else {
          vc.latitude = [self latitudeFromTextField];
          vc.longitude = [self longitudeFromTextField];

          if (vc.latitude == 0 && vc.longitude == 0) {
            vc.latitude = _locationManager.location.coordinate.latitude;
            vc.longitude = _locationManager.location.coordinate.longitude;
          }
        }

        vc.delegate = self;
        [self presentViewController:vc animated:YES completion:nil];
      }
  ];

  otherAction = [UIAlertAction actionWithTitle:@"Cancel"
                                         style:UIAlertActionStyleCancel
                                       handler:
      ^(UIAlertAction *action) {
        _saveButton.enabled = YES;
        _cancelButton.enabled = YES;
      }
  ];

  [alertController addAction:pickPlaceAction];
  [alertController addAction:currentLocationAction];
  [alertController addAction:chooseLocationAction];
  [alertController addAction:otherAction];
  [alertController setModalPresentationStyle:UIModalPresentationPopover];
  
  [self presentViewController:alertController animated:YES completion:nil];
}

- (double)latitudeFromTextField {
  NSArray *parts = [_locationTextField.text componentsSeparatedByString:@","];
  return ((NSString *)parts[0]).doubleValue;
}

- (double)longitudeFromTextField {
  NSArray *parts = [_locationTextField.text componentsSeparatedByString:@","];
  return ((NSString *)parts[1]).doubleValue;
}

@end
