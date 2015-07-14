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
import android.os.AsyncTask;
import android.util.Log;
import com.google.android.gms.auth.GoogleAuthException;
import com.google.android.gms.auth.GoogleAuthUtil;
import com.google.android.gms.auth.UserRecoverableAuthException;

import java.io.IOException;

/**
 * NOP async task that allows us to check if a new user has authorized the app
 * to access their account.
 */
class AuthorizedServiceTask extends AsyncTask<Void, Void, Void> {
  private static final String TAG = AuthorizedServiceTask.class.getSimpleName();

  private final Activity activity;
  private final String accountName;

  public AuthorizedServiceTask(Activity activity, String accountName) {
    this.activity = activity;
    this.accountName = accountName;
  }

  @Override
  protected Void doInBackground(Void... params) {
    Log.i(TAG, "checking authorization for " + accountName);
    try {
      GoogleAuthUtil.getToken(activity, accountName, Constants.AUTH_SCOPE);
    } catch (UserRecoverableAuthException e) {
      // GooglePlayServices.apk is either old, disabled, or not present
      // so we need to show the user some UI in the activity to recover.
      Utils.handleAuthException(activity, e);
    } catch (GoogleAuthException e) {
      // Some other type of unrecoverable exception has occurred.
      // Report and log the error as appropriate for your app.
      Log.w(TAG, "GoogleAuthException: " + e);
    } catch (IOException e) {
      // The fetchToken() method handles Google-specific exceptions,
      // so this indicates something went wrong at a higher level.
      // TIP: Check for network connectivity before starting the AsyncTask.
    }
    return null;
  }

}
