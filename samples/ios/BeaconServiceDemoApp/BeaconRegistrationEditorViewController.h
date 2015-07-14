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

@class BeaconRegistrationEditorViewController;

@protocol BeaconRegistrationEditorViewControllerDelegate <NSObject>
@optional

- (void)beaconRegistrationEditor:(BeaconRegistrationEditorViewController *)editor
               didRegisterBeacon:(NSDictionary *)beaconInfo;

- (void)beaconRegistrationEditor:(BeaconRegistrationEditorViewController *)editor
                 didUpdateBeacon:(NSDictionary *)beaconInfo;

@end

@interface BeaconRegistrationEditorViewController : UIViewController

@property(nonatomic, copy) NSDictionary *existingBeaconInfo;
@property(nonatomic, copy) NSString *beaconID;
@property(nonatomic, weak) id<BeaconRegistrationEditorViewControllerDelegate> delegate;

@end
