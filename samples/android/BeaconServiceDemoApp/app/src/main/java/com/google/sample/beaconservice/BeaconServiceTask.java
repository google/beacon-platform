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

import com.android.volley.AuthFailureError;
import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.Response;
import com.android.volley.toolbox.JsonObjectRequest;
import com.google.android.gms.auth.GoogleAuthException;
import com.google.android.gms.auth.GoogleAuthUtil;
import com.google.android.gms.auth.UserRecoverableAuthException;

import org.json.JSONObject;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * An AsyncTask that manages the communication with the proximity beacon service.
 *
 * For more information on the beacon proximity service APIs see:
 * https://developers.google.com/beacon/proximity/
 *
 * For more information on the authentication mechanism, see:
 * https://developers.google.com/android/guides/http-auth
 */
class BeaconServiceTask extends AsyncTask<Object, Object, Object> {
  private static final String TAG = BeaconServiceTask.class.getSimpleName();

  private static final String SERVICE_ENDPOINT = "https://proximitybeacon.googleapis.com/v1beta1/";

  private final Activity activity;
  private final String accountName;

  private final int requestMethod;
  private final String urlPath;
  private final JSONObject body;
  private final Response.Listener<JSONObject> responseListener;
  private final Response.ErrorListener errorListener;

  /**
   * Creates a request without a body.
   */
  public BeaconServiceTask(Activity activity,
                           String accountName,
                           int requestMethod,
                           String urlPath,
                           Response.Listener<JSONObject> responseListener,
                           Response.ErrorListener errorListener) {
    this(activity, accountName, requestMethod, urlPath, new JSONObject(),
        responseListener, errorListener);
  }

  /**
   * Creates a request with a body.
   */
  public BeaconServiceTask(Activity activity,
                           String accountName,
                           int requestMethod,
                           String urlPath,
                           JSONObject body,
                           Response.Listener<JSONObject> responseListener,
                           Response.ErrorListener errorListener) {
    this.activity = activity;
    this.accountName = accountName;
    this.requestMethod = requestMethod;
    this.urlPath = urlPath;
    this.body = body;
    this.responseListener = responseListener;
    this.errorListener = errorListener;
  }

  private String getRequestMethodName() {
    switch (requestMethod) {
      case Request.Method.GET:
        return "GET";
      case Request.Method.PUT:
        return "PUT";
      case Request.Method.POST:
        return "POST";
      case Request.Method.DELETE:
        return "DELETE";
      default: return "default";
    }
  }

  @Override
  protected String doInBackground(Object... params) {
    try {
      final String token = GoogleAuthUtil.getToken(activity, accountName, Constants.AUTH_SCOPE);
      String url = SERVICE_ENDPOINT + urlPath;
      JsonObjectRequest request = new JsonObjectRequest(
          requestMethod, url, body, responseListener, errorListener) {
        @Override
        public Map<String, String> getHeaders() throws AuthFailureError {
          Map<String, String> headers = new HashMap<>();
          headers.put("Authorization", "Bearer " + token);
          return headers;
        }
      };
      int initialTimeoutSeconds = requestMethod == Request.Method.GET ? 10 : 15;
      request.setRetryPolicy(new DefaultRetryPolicy(initialTimeoutSeconds * 1000,
          DefaultRetryPolicy.DEFAULT_MAX_RETRIES, DefaultRetryPolicy.DEFAULT_BACKOFF_MULT));
      String logMsg = getRequestMethodName() + " " + url;
      if (body != null && body.length() > 0) {
        logMsg += ", body: " + body.toString();
      }
      Log.i(TAG, logMsg);
      RequestQueue requestQueue = RequestQueueManager.getRequestQueue(activity);
      requestQueue.add(request);
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
