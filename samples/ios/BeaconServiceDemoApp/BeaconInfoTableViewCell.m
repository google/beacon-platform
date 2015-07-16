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

#import "BeaconInfoTableViewCell.h"

// Default location coordinate 2D in case of missing values requirements.
CLLocationCoordinate2D const kDefaultLocationCoordinate2D = (CLLocationCoordinate2D){37.42242 , -122.08430};

@interface BeaconInfoTableViewCell () {
  GMSMapView *_mapView;
  CGRect _mapViewFrame;

}
@property (strong, nonatomic) IBOutlet UILabel *beaconIDLabel;
@property (strong, nonatomic) IBOutlet UILabel *beaconTypeLabel;
@property (strong, nonatomic) IBOutlet UILabel *beaconLatLngLabel;
@property (strong, nonatomic) IBOutlet UILabel *beaconStatusLabel;
@property (strong, nonatomic) IBOutlet UIImageView *imageBackground;

@end

@implementation BeaconInfoTableViewCell

- (void)awakeFromNib {
    // Initialization code
  self.layoutMargins = UIEdgeInsetsZero;
  self.contentView.backgroundColor = [UIColor colorWithRed:0.74 green:0.9 blue:0.98 alpha:1];

  _mapViewFrame = CGRectMake(8, 106, self.contentView.frame.size.width - 32, 94);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (_mapView) {
  _mapView.frame = CGRectMake(8, 106, self.contentView.frame.size.width - 16, 94);
  }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setBeaconID:(NSString *)beaconID {
  _beaconIDLabel.text = beaconID;
}

- (void)setBeaconType:(NSString *)beaconType {
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
  [text appendAttributedString:[self makeTextMediumBold:@"Type: "]];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:beaconType]];
  _beaconTypeLabel.attributedText = text;
}

- (void)setBeaconLocation:(NSDictionary *)beaconLocation {

  if (beaconLocation[@"placeId"]) {
    [[GMSPlacesClient sharedClient] lookUpPlaceID:beaconLocation[@"placeId"] callback:
        ^(GMSPlace *place, NSError *error) {
          if (!error) {
            NSMutableAttributedString *text =
                [[NSMutableAttributedString alloc] initWithString:@""];
            [text appendAttributedString:[self makeTextMediumBold:@"Place: "]];
            [text appendAttributedString:[[NSAttributedString alloc] initWithString:place.name]];
            _beaconLatLngLabel.attributedText = text;
            [self setMapViewToLatitude:place.coordinate.latitude
                             longitude:place.coordinate.longitude];
          } else {
            // TODO(developer): Maybe report the error here and try again?
            _beaconLatLngLabel.text = beaconLocation[@"placeId"];
            [self setMapViewToLatitude:0 longitude:0];
          }
        }
    ];
  } else if (beaconLocation[@"latLng"]){
    
    CLLocationCoordinate2D coordinate =
      CLLocationCoordinate2DMake([beaconLocation[@"latLng"][@"latitude"] doubleValue],
                                 [beaconLocation[@"latLng"][@"longitude"] doubleValue]);
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    [text appendAttributedString:[self makeTextMediumBold:@"Lat: "]];
    [text appendAttributedString:[[NSAttributedString alloc]
                                  initWithString:[@(coordinate.latitude) stringValue]]];
    [text appendAttributedString:[self makeTextMediumBold:@" Lon: "]];
    [text appendAttributedString:[[NSAttributedString alloc]
                                  initWithString:[@(coordinate.longitude) stringValue]]];
    _beaconLatLngLabel.attributedText = text;

    [self setMapViewToLatitude:coordinate.latitude longitude:coordinate.longitude];
  }
  else {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    [text appendAttributedString:[self makeTextMediumBold:@"Location: "]];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"(not specified)"]];
    _beaconLatLngLabel.attributedText = text;
  
    // Just set the location to somewhere known instead of (0,0) which is in the Atlantic somewhere.
    [self setMapViewToLatitude:kDefaultLocationCoordinate2D.latitude
                     longitude:kDefaultLocationCoordinate2D.longitude];
  }
}

- (void)setMapViewToLatitude:(double)latitude longitude:(double)longitude {
  if (!_mapView) {
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude
                                                            longitude:longitude
                                                                 zoom:14];
    _mapView = [GMSMapView mapWithFrame:_mapViewFrame camera:camera];
    _mapView.layer.cornerRadius = 5;

    [self.contentView addSubview:_mapView];
  } else {
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude
                                                            longitude:longitude
                                                                 zoom:14];
    _mapView.camera = camera;
  }

  CLLocationCoordinate2D position = CLLocationCoordinate2DMake(latitude, longitude);
  GMSMarker *marker = [GMSMarker markerWithPosition:position];
  marker.map = _mapView;

}

- (void)setBeaconStatus:(NSString *)beaconStatus {
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
  [text appendAttributedString:[self makeTextMediumBold:@"Status: "]];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:beaconStatus]];
  _beaconStatusLabel.attributedText = text;
}

- (NSAttributedString *)makeTextMediumBold:(NSString *)value {
  NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:value];
  [str addAttribute:NSFontAttributeName
              value:[UIFont fontWithName:@"Helvetica-Bold" size:16.0]
              range:NSMakeRange(0, [str length])];
  return str;
}

@end
