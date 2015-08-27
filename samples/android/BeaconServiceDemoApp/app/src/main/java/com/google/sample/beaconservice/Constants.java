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

package com.google.sample.beaconservice;

class Constants {
  private Constants() {}

  static final int REQUEST_CODE_PICK_ACCOUNT = 1000;
  static final int REQUEST_CODE_ENABLE_BLE = 1001;
  static final int REQUEST_CODE_RECOVER_FROM_PLAY_SERVICES_ERROR = 1002;
  static final int REQUEST_CODE_PLACE_PICKER = 1003;

  static final String AUTH_SCOPE = "oauth2:https://www.googleapis.com/auth/userlocation.beacon.registry";
  static final String PREFS_NAME = "com.google.sample.beaconservice.Prefs";
}
