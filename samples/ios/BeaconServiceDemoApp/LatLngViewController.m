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

@import GoogleMaps;

#import "LatLngViewController.h"

@interface LatLngViewController () <GMSMapViewDelegate> {
  GMSMapView *_mapView;
  GMSMarker *_marker;
}

@property (strong, nonatomic) IBOutlet UIButton *saveButton;
@property (strong, nonatomic) IBOutlet UIView *mainView;

@end

@implementation LatLngViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:_latitude
                                                          longitude:_longitude
                                                               zoom:14];
  CGRect m = _mainView.bounds;
  CGRect fr = CGRectMake(0, 0, m.size.width, m.size.height + 70);
   _mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
   [_mainView addSubview:_mapView];
  _mapView.frame = fr;
  _mapView.delegate = self;

  CLLocationCoordinate2D position = CLLocationCoordinate2DMake(_latitude, _longitude);
  _marker = [GMSMarker markerWithPosition:position];
  _marker.map = _mapView;
}


- (IBAction)saveButtonPressed:(id)sender {
  if ([_delegate respondsToSelector:@selector(latLngEntry:didEnterLatitude:longitude:)]) {
    [_delegate latLngEntry:self
          didEnterLatitude:_marker.position.latitude
                 longitude:_marker.position.longitude];
  }

  [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  GMSMarker *newMarker = [GMSMarker markerWithPosition:coordinate];
  _marker.map = nil;
  newMarker.map = _mapView;
  _marker = newMarker;
}

@end
