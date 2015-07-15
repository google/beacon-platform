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
  } else {
    
    beaconLocation = [self normalizedBeaconLocationFromBeaconLocationInfo:beaconLocation];
      
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    [text appendAttributedString:[self makeTextMediumBold:@"Lat: "]];
    [text appendAttributedString:[[NSAttributedString alloc]
        initWithString:[(NSNumber *)beaconLocation[@"latitude"] stringValue]]];
    [text appendAttributedString:[self makeTextMediumBold:@" Lon: "]];
    [text appendAttributedString:[[NSAttributedString alloc]
        initWithString:[(NSNumber *)beaconLocation[@"longitude"] stringValue]]];
    _beaconLatLngLabel.attributedText = text;

    double lat = [(NSNumber *)beaconLocation[@"latitude"] doubleValue];
    double lon = [(NSNumber *)beaconLocation[@"longitude"] doubleValue];
    [self setMapViewToLatitude:lat longitude:lon];
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

#pragma mark Helper method

/**
 *  Convenience method for normaliz-ing a beacon location dictionary to properly conform to required values.
 *
 *  @param beaconLocation A beacon location info dictionary.
 *
 *  @return A normalized beacon location with missing values from in input beacon location replaced by default values.
 *
 *  @discuss Missing longitude and latitude values are replaced with default value: 0,0
 */
- (NSDictionary *)normalizedBeaconLocationFromBeaconLocationInfo:(NSDictionary *)beaconLocation
{
    if (!beaconLocation[@"longitude"] || !beaconLocation[@"latitude"]) {
        // Received beacon location do not conform to required values.
        // In case no values have been entered for latitude or longitutide "0,0" is inferred as default value.
        
        // Create an hougin for the normalized beacon location
        NSMutableDictionary *normalizedBeaconLocation = [NSMutableDictionary dictionary];
        
        // Normalize longitude if needed
        if (!beaconLocation[@"longitude"]) {
            NSLog(@"A beacon location with longitude 0,0 is inferred");
            [normalizedBeaconLocation setObject:@(0.0) forKey:@"longitude"];
        }
        
        // Normalize latitude if needed
        if (!beaconLocation[@"latitude"]) {
            NSLog(@"A beacon location with longitude 0,0 is inferred");
            [normalizedBeaconLocation setObject:@(0.0) forKey:@"latitude"];
        }
        
        return [normalizedBeaconLocation copy];
    }
    
    return beaconLocation;
}

@end
