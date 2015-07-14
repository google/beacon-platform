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
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.util.Log;
import android.view.View;
import android.widget.Toast;

import com.android.volley.Response;
import com.android.volley.VolleyError;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * A Response.ErrorListener that shows an alert dialog.
 */
class AlertingErrorListener {
  private AlertingErrorListener() {}

  public static Response.ErrorListener create(final Activity activity,
                                              final String logTag) {
    return create(activity, logTag, null, null);
  }

  public static Response.ErrorListener create(final Activity activity,
                                              final String logTag,
                                              final View[] viewsToEnable,
                                              final View[] viewsToDisable) {
    return new Response.ErrorListener() {
      @Override
      public void onErrorResponse(VolleyError error) {
        try {
          // Get the JSON error if we can.
          String errorMessage;
          if (error.networkResponse != null && error.networkResponse.data != null) {
            JSONObject err = new JSONObject(new String(error.networkResponse.data));
            errorMessage = err.toString(2);
          } else {
            errorMessage = error.toString();
          }
          Log.w(logTag, errorMessage);
          new AlertDialog.Builder(activity)
              .setTitle("Error")
              .setMessage(errorMessage)
              .setPositiveButton("OK", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                  dialog.dismiss();
                }
              })
              .show();
        } catch (JSONException e) {
          Toast.makeText(
              activity, "Bad network error response: " + error, Toast.LENGTH_LONG).show();
        }
        Utils.setEnabledViews(true, viewsToEnable);
        Utils.setEnabledViews(false, viewsToDisable);
      }
    };
  }

}
