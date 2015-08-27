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

import android.app.Activity;
import android.app.Dialog;
import android.content.Intent;
import android.util.Base64;
import android.view.View;

import com.google.android.gms.auth.GooglePlayServicesAvailabilityException;
import com.google.android.gms.auth.UserRecoverableAuthException;
import com.google.android.gms.common.GooglePlayServicesUtil;


class Utils {
  private Utils() {}  // static functions only

  private static final char[] HEX = "0123456789ABCDEF".toCharArray();

  static byte[] base64Decode(String s) {
    return Base64.decode(s, Base64.DEFAULT);
  }

  static String base64Encode(byte[] b) {
    return Base64.encodeToString(b, Base64.DEFAULT).trim();
  }

  static String toHexString(byte[] bytes) {
    char[] chars = new char[bytes.length * 2];
    for (int i = 0; i < bytes.length; i++) {
      int c = bytes[i] & 0xFF;
      chars[i * 2] = HEX[c >>> 4];
      chars[i * 2 + 1] = HEX[c & 0x0F];
    }
    return new String(chars).toLowerCase();
  }

  static void handleAuthException(final Activity activity, final Exception e) {
    activity.runOnUiThread(new Runnable() {
      @Override
      public void run() {
        if (e instanceof GooglePlayServicesAvailabilityException) {
          // The Google Play services APK is old, disabled, or not present.
          // Show a dialog created by Google Play services that allows
          // the user to update the APK
          int statusCode = ((GooglePlayServicesAvailabilityException)e).getConnectionStatusCode();
          Dialog dialog = GooglePlayServicesUtil.getErrorDialog(
            statusCode, activity, Constants.REQUEST_CODE_RECOVER_FROM_PLAY_SERVICES_ERROR);
          dialog.show();
        }
        else if (e instanceof UserRecoverableAuthException) {
          // Unable to authenticate, such as when the user has not yet granted
          // the app access to the account, but the user can fix this.
          // Forward the user to an activity in Google Play services.
          Intent intent = ((UserRecoverableAuthException)e).getIntent();
          activity.startActivityForResult(
            intent, Constants.REQUEST_CODE_RECOVER_FROM_PLAY_SERVICES_ERROR);
        }
      }
    });
  }

  static void setEnabledViews(boolean enabled, View... views) {
    if (views == null || views.length == 0) {
      return;
    }
    for (View v : views) {
      v.setEnabled(enabled);
    }
  }

}
